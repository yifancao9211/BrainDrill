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

    @Test func staircaseAdvancesOnCorrect() {
        let config = CorsiBlockSessionConfig(startingLength: 3)
        let engine = CorsiBlockEngine(config: config)

        engine.beginNextTrial()
        _ = engine.submitResponse(engine.currentTrial!.expectedResponse)
        engine.advanceAfterFeedback()

        // 1-up：答对即升一档。
        #expect(engine.currentLength == 4)
    }

    @Test func staircaseDemotesOnWrong() {
        let config = CorsiBlockSessionConfig(startingLength: 5, minLength: 2)
        let engine = CorsiBlockEngine(config: config)

        engine.beginNextTrial()
        _ = engine.submitResponse([99])
        engine.advanceAfterFeedback()

        // 1-down：答错即降一档。
        #expect(engine.currentLength == 4)
    }

    @Test func minLengthFloorRespected() {
        let config = CorsiBlockSessionConfig(startingLength: 2, minLength: 2)
        let engine = CorsiBlockEngine(config: config)

        engine.beginNextTrial()
        _ = engine.submitResponse([99])
        engine.advanceAfterFeedback()

        #expect(engine.currentLength == 2)
    }

    @Test func completesAfterReversalTarget() {
        let config = CorsiBlockSessionConfig(startingLength: 3, reversalsToComplete: 4, maxTrials: 100)
        let engine = CorsiBlockEngine(config: config)

        engine.beginNextTrial()
        var stepCorrect = true
        var guardCount = 0
        while !engine.isComplete && guardCount < 100 {
            if stepCorrect {
                _ = engine.submitResponse(engine.currentTrial!.expectedResponse)
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

    /// 持续答错时方向不反转，由 maxTrials 安全上限兜底结束。
    @Test func sessionEndsAtTrialCap() {
        let config = CorsiBlockSessionConfig(startingLength: 4, minLength: 2, reversalsToComplete: 6, maxTrials: 5)
        let engine = CorsiBlockEngine(config: config)

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
        #expect(CorsiBlockEngine.threshold(from: [5, 4], fallback: 0) == 4.5)
        #expect(CorsiBlockEngine.threshold(from: [3, 7, 6, 4], fallback: 0) == 5)
        #expect(CorsiBlockEngine.threshold(from: [], fallback: 6) == 6)
    }

    @Test func metricsComputed() {
        let config = CorsiBlockSessionConfig(startingLength: 3, maxTrials: 2)
        let engine = CorsiBlockEngine(config: config)

        engine.beginNextTrial()
        _ = engine.submitResponse(engine.currentTrial!.expectedResponse)
        engine.advanceAfterFeedback()
        _ = engine.submitResponse([99])
        engine.advanceAfterFeedback()

        #expect(engine.isComplete)
        let m = engine.computeMetrics()
        #expect(m.totalTrials == 2)
        #expect(m.correctTrials == 1)
        #expect(m.maxSpan >= 3)
    }
}
