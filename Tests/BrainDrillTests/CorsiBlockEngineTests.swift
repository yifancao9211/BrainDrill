import Foundation
import Testing
@testable import BrainDrill

struct CorsiBlockEngineTests {
    @Test func startsAtConfiguredLength() {
        let config = CorsiBlockSessionConfig(startingLength: 3)
        let engine = CorsiBlockEngine(config: config)
        #expect(engine.currentLength == 3)
        #expect(engine.phase == .idle)
    }

    @Test func generatesSequenceOfCorrectLength() {
        let config = CorsiBlockSessionConfig(startingLength: 4)
        let engine = CorsiBlockEngine(config: config)
        engine.beginNextTrial()
        #expect(engine.currentTrial?.sequence.count == 4)
        #expect(engine.phase == .presenting)
    }

    @Test func sequenceUsesValidBlockIndices() {
        let config = CorsiBlockSessionConfig(startingLength: 5, gridSize: 9)
        let engine = CorsiBlockEngine(config: config)
        engine.beginNextTrial()
        let seq = engine.currentTrial!.sequence
        for idx in seq {
            #expect(idx >= 0 && idx < 9)
        }
    }

    @Test func sequenceDoesNotRepeatPositions() {
        let config = CorsiBlockSessionConfig(startingLength: 7, gridSize: 9)
        let engine = CorsiBlockEngine(config: config)
        engine.beginNextTrial()
        let seq = engine.currentTrial!.sequence
        #expect(Set(seq).count == seq.count)
    }

    @Test func correctForwardResponse() {
        let trial = CorsiBlockTrial(id: 0, sequence: [2, 5, 7], mode: .forward)
        let result = CorsiBlockTrialResult(trial: trial, userInput: [2, 5, 7])
        #expect(result.correct)
        #expect(result.positionErrors == 0)
    }

    @Test func correctBackwardResponse() {
        let trial = CorsiBlockTrial(id: 0, sequence: [2, 5, 7], mode: .backward)
        #expect(trial.expectedResponse == [7, 5, 2])
        let result = CorsiBlockTrialResult(trial: trial, userInput: [7, 5, 2])
        #expect(result.correct)
    }

    @Test func wrongResponseCountsPositionErrors() {
        let trial = CorsiBlockTrial(id: 0, sequence: [1, 3, 5], mode: .forward)
        let result = CorsiBlockTrialResult(trial: trial, userInput: [1, 5, 3])
        #expect(!result.correct)
        #expect(result.positionErrors == 2)
    }

    @Test func staircaseAdvancesOnConsecutiveCorrect() {
        let config = CorsiBlockSessionConfig(startingLength: 3, consecutiveCorrectToAdvance: 2, consecutiveWrongToDemote: 2)
        let engine = CorsiBlockEngine(config: config)

        engine.beginNextTrial()
        _ = engine.submitResponse(engine.currentTrial!.expectedResponse)
        engine.advanceAfterFeedback()

        _ = engine.submitResponse(engine.currentTrial!.expectedResponse)
        engine.advanceAfterFeedback()

        #expect(engine.currentLength == 4)
    }

    @Test func staircaseEndsOnConsecutiveWrong() {
        let config = CorsiBlockSessionConfig(startingLength: 3, consecutiveCorrectToAdvance: 2, consecutiveWrongToDemote: 2)
        let engine = CorsiBlockEngine(config: config)

        engine.beginNextTrial()
        _ = engine.submitResponse([99])
        engine.advanceAfterFeedback()

        _ = engine.submitResponse([99])
        engine.advanceAfterFeedback()

        #expect(engine.isComplete)
    }

    @Test func metricsComputed() {
        let config = CorsiBlockSessionConfig(startingLength: 3, consecutiveWrongToDemote: 1)
        let engine = CorsiBlockEngine(config: config)

        engine.beginNextTrial()
        _ = engine.submitResponse(engine.currentTrial!.expectedResponse)
        engine.advanceAfterFeedback()
        _ = engine.submitResponse([99])
        engine.advanceAfterFeedback()

        let m = engine.computeMetrics()
        #expect(m.totalTrials == 2)
        #expect(m.correctTrials == 1)
        #expect(m.maxSpan >= 3)
    }
}
