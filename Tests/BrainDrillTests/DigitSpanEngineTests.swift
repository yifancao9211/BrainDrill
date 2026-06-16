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
        let config = DigitSpanSessionConfig(startingLength: 3, mode: .forward)
        let engine = DigitSpanEngine(config: config)

        engine.beginNextTrial()
        let seq1 = engine.currentTrial!.sequence
        _ = engine.submitResponse(seq1)
        engine.advanceAfterFeedback()

        // 1-up：答对即升一档。
        #expect(engine.currentLength == 4)
    }

    @Test func wrongResponseDemotesSpan() {
        let config = DigitSpanSessionConfig(startingLength: 5, minLength: 2, mode: .forward)
        let engine = DigitSpanEngine(config: config)

        engine.beginNextTrial()
        _ = engine.submitResponse([99, 99, 99, 99, 99])
        engine.advanceAfterFeedback()

        // 1-down：答错即降一档。
        #expect(engine.currentLength == 4)
    }

    @Test func minLengthFloorRespected() {
        let config = DigitSpanSessionConfig(startingLength: 2, minLength: 2, mode: .forward)
        let engine = DigitSpanEngine(config: config)

        engine.beginNextTrial()
        _ = engine.submitResponse([99, 99])
        engine.advanceAfterFeedback()

        #expect(engine.currentLength == 2)
    }

    @Test func completesAfterReversalTarget() {
        // 起步 3，alternating 对/错会持续产生方向反转，应在满 reversalsToComplete 时结束。
        let config = DigitSpanSessionConfig(
            startingLength: 3,
            mode: .forward,
            reversalsToComplete: 4,
            maxTrials: 100
        )
        let engine = DigitSpanEngine(config: config)

        engine.beginNextTrial()
        var stepCorrect = true
        var guardCount = 0
        while !engine.isComplete && guardCount < 100 {
            if stepCorrect {
                _ = engine.submitResponse(engine.currentTrial!.sequence)
            } else {
                _ = engine.submitResponse([99])
            }
            engine.advanceAfterFeedback()
            stepCorrect.toggle()
            guardCount += 1
        }

        #expect(engine.isComplete)
        #expect(engine.reversalCount >= config.reversalsToComplete)
    }

    @Test func maxTrialsBackstopEndsSession() {
        // 持续答错时方向不反转，由 maxTrials 安全上限兜底结束。
        let config = DigitSpanSessionConfig(
            startingLength: 4,
            minLength: 2,
            mode: .forward,
            reversalsToComplete: 6,
            maxTrials: 5
        )
        let engine = DigitSpanEngine(config: config)

        engine.beginNextTrial()
        var guardCount = 0
        while !engine.isComplete && guardCount < 50 {
            _ = engine.submitResponse([99])
            engine.advanceAfterFeedback()
            guardCount += 1
        }

        #expect(engine.isComplete)
        #expect(engine.trialIndex >= config.maxTrials)
    }

    @Test func thresholdAveragesReversalPoints() {
        // 反转点 [5,4] -> 不足 4 个不丢弃 -> 均值 4.5。
        #expect(DigitSpanEngine.threshold(from: [5, 4], fallback: 0) == 4.5)
        // 反转点 4 个，丢弃前两次预热 -> 仅用后两个 [6,4] -> 均值 5。
        #expect(DigitSpanEngine.threshold(from: [3, 7, 6, 4], fallback: 0) == 5)
        // 无反转时回退到峰值。
        #expect(DigitSpanEngine.threshold(from: [], fallback: 6) == 6)
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
        let config = DigitSpanSessionConfig(startingLength: 3, mode: .forward, maxTrials: 2)
        let engine = DigitSpanEngine(config: config)

        engine.beginNextTrial()
        let seq = engine.currentTrial!.sequence
        _ = engine.submitResponse(seq)
        engine.advanceAfterFeedback()

        _ = engine.submitResponse(Array(engine.currentTrial!.sequence.dropLast()))
        engine.advanceAfterFeedback()

        #expect(engine.isComplete)
        let m = engine.computeMetrics()
        #expect(m.totalTrials == 2)
        #expect(m.correctTrials == 1)
        #expect(m.accuracy == 0.5)
        #expect(m.maxSpanForward >= 3)
    }
}
