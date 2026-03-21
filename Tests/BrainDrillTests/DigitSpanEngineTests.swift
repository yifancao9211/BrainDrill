import Foundation
import Testing
@testable import BrainDrill

struct DigitSpanEngineTests {
    @Test func startsAtConfiguredLength() {
        let config = DigitSpanSessionConfig(startingLength: 4, mode: .forward)
        let engine = DigitSpanEngine(config: config)
        #expect(engine.currentLength == 4)
        #expect(engine.phase == .idle)
    }

    @Test func generatesSequenceOfCorrectLength() {
        let config = DigitSpanSessionConfig(startingLength: 5, mode: .forward)
        let engine = DigitSpanEngine(config: config)
        engine.beginNextTrial()
        #expect(engine.currentTrial?.length == 5)
        #expect(engine.currentTrial?.sequence.count == 5)
        #expect(engine.phase == .presenting)
    }

    @Test func noConsecutiveDuplicateDigits() {
        let config = DigitSpanSessionConfig(startingLength: 8, mode: .forward)
        let engine = DigitSpanEngine(config: config)
        engine.beginNextTrial()
        guard let seq = engine.currentTrial?.sequence else {
            Issue.record("No trial generated")
            return
        }
        for i in 1..<seq.count {
            #expect(seq[i] != seq[i - 1])
        }
    }

    @Test func correctResponseAdvancesSpan() {
        let config = DigitSpanSessionConfig(
            startingLength: 3,
            mode: .forward,
            consecutiveCorrectToAdvance: 2,
            consecutiveWrongToDemote: 2
        )
        let engine = DigitSpanEngine(config: config)

        engine.beginNextTrial()
        let seq1 = engine.currentTrial!.sequence
        _ = engine.submitResponse(seq1)
        engine.advanceAfterFeedback()

        let seq2 = engine.currentTrial!.sequence
        _ = engine.submitResponse(seq2)
        engine.advanceAfterFeedback()

        #expect(engine.currentLength == 4)
    }

    @Test func wrongResponsesDemote() {
        let config = DigitSpanSessionConfig(
            startingLength: 3,
            mode: .forward,
            consecutiveCorrectToAdvance: 2,
            consecutiveWrongToDemote: 2
        )
        let engine = DigitSpanEngine(config: config)

        engine.beginNextTrial()
        _ = engine.submitResponse([99, 99, 99])
        engine.advanceAfterFeedback()

        _ = engine.submitResponse([99, 99, 99])
        #expect(engine.phase == .feedback(correct: false))
        engine.advanceAfterFeedback()

        #expect(engine.isComplete)
    }

    @Test func backwardModeReversesExpected() {
        let trial = DigitSpanTrial(id: 0, sequence: [1, 2, 3], mode: .backward)
        #expect(trial.expectedResponse == [3, 2, 1])

        let result = DigitSpanTrialResult(trial: trial, userInput: [3, 2, 1])
        #expect(result.correct)
        #expect(result.positionErrors == 0)
    }

    @Test func positionErrorsCounted() {
        let trial = DigitSpanTrial(id: 0, sequence: [5, 3, 7], mode: .forward)
        let result = DigitSpanTrialResult(trial: trial, userInput: [5, 7, 3])
        #expect(!result.correct)
        #expect(result.positionErrors == 2)
    }

    @Test func metricsComputed() {
        let config = DigitSpanSessionConfig(startingLength: 3, mode: .forward, consecutiveWrongToDemote: 1)
        let engine = DigitSpanEngine(config: config)

        engine.beginNextTrial()
        let seq = engine.currentTrial!.sequence
        _ = engine.submitResponse(seq)
        engine.advanceAfterFeedback()

        _ = engine.submitResponse([99])
        engine.advanceAfterFeedback()

        let m = engine.computeMetrics()
        #expect(m.totalTrials == 2)
        #expect(m.correctTrials == 1)
        #expect(m.accuracy == 0.5)
        #expect(m.maxSpanForward >= 3)
    }
}
