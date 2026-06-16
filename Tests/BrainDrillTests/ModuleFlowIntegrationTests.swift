import Foundation
import Testing
@testable import BrainDrill

struct ChangeDetectionFlowTests {
    @Test func fullSessionFlow() {
        let config = ChangeDetectionSessionConfig(initialSetSize: 3, trialsPerBlock: 5, blockCount: 1)
        let engine = ChangeDetectionEngine(config: config)

        engine.beginTrial()
        #expect(engine.phase == .encoding)
        #expect(engine.currentTrial != nil)

        engine.startRetention()
        #expect(engine.phase == .retention)

        engine.showProbe()
        #expect(engine.phase == .probe)

        let trial = engine.currentTrial!
        let result = engine.recordResponse(userSaidChanged: trial.isChangePresent)
        #expect(result?.correct == true)

        engine.advanceToNext()
    }

    @Test func completeAllTrials() {
        let config = ChangeDetectionSessionConfig(initialSetSize: 3, trialsPerBlock: 5, blockCount: 1)
        let engine = ChangeDetectionEngine(config: config)

        for _ in 0..<5 {
            engine.beginTrial()
            engine.startRetention()
            engine.showProbe()
            let trial = engine.currentTrial!
            _ = engine.recordResponse(userSaidChanged: trial.isChangePresent)
            engine.advanceToNext()
        }

        #expect(engine.isComplete)
        let m = engine.computeMetrics()
        #expect(m.accuracy > 0.99)
    }
}

struct NBackFlowTests {
    @Test func autoPacedStimulusFlow() {
        let config = NBackSessionConfig(startingN: 1, trialsPerBlock: 5, blockCount: 1)
        let engine = NBackEngine(config: config)

        engine.beginTrial()
        #expect(engine.phase == .stimulus)
        #expect(engine.currentStimulus != nil)

        engine.enterISI()
        #expect(engine.phase == .isi)

        engine.advanceTrial()
        #expect(engine.phase == .stimulus)
        #expect(engine.currentTrialIndex == 1)
    }

    @Test func matchResponseFlow() {
        let config = NBackSessionConfig(startingN: 1, trialsPerBlock: 10, blockCount: 1)
        let engine = NBackEngine(config: config)

        while !engine.isComplete {
            switch engine.phase {
            case .idle:
                engine.beginTrial()
            case .stimulus:
                // Respond "match" only on targets (single-key paradigm).
                if engine.currentTrialIndex >= engine.currentN && engine.isTarget {
                    engine.recordMatch(at: Date())
                }
                engine.enterISI()
            case .isi:
                engine.advanceTrial()
            case .practiceComplete:
                engine.beginTrial()
            case let .blockBreak(_, nextN):
                engine.startNextBlock(n: nextN)
            case .completed:
                break
            }
        }

        #expect(engine.isComplete)
        let m = engine.computeMetrics()
        #expect(m.hitRate > 0)
        #expect(m.dPrime > 0)
    }
}

struct DigitSpanFlowTests {
    @Test func presentRecallFlow() {
        let config = DigitSpanSessionConfig(startingLength: 3, mode: .forward)
        let engine = DigitSpanEngine(config: config)

        engine.beginNextTrial()
        #expect(engine.phase == .presenting)
        #expect(engine.currentTrial != nil)

        while engine.advancePresentingDigit() {}
        engine.finishPresenting()
        #expect(engine.phase == .recalling)

        let seq = engine.currentTrial!.sequence
        let result = engine.submitResponse(seq)
        #expect(result.correct)

        if case .feedback(let correct) = engine.phase {
            #expect(correct)
        }

        engine.advanceAfterFeedback()
    }

    @Test func reachingTrialCapEndsSession() {
        let config = DigitSpanSessionConfig(startingLength: 3, mode: .forward, maxTrials: 1)
        let engine = DigitSpanEngine(config: config)

        engine.beginNextTrial()
        while engine.advancePresentingDigit() {}
        engine.finishPresenting()

        _ = engine.submitResponse([99, 99, 99])
        engine.advanceAfterFeedback()

        #expect(engine.isComplete)
    }
}

struct CorsiBlockFlowTests {
    @Test func presentRecallFlow() {
        let config = CorsiBlockSessionConfig(startingLength: 3)
        let engine = CorsiBlockEngine(config: config)

        engine.beginNextTrial()
        #expect(engine.phase == .presenting)

        while engine.advancePresentingBlock() {}
        engine.finishPresenting()
        #expect(engine.phase == .recalling)

        let expected = engine.currentTrial!.expectedResponse
        let result = engine.submitResponse(expected)
        #expect(result.correct)
    }

    @Test func reachingTrialCapEndsSession() {
        let config = CorsiBlockSessionConfig(startingLength: 3, maxTrials: 1)
        let engine = CorsiBlockEngine(config: config)

        engine.beginNextTrial()
        while engine.advancePresentingBlock() {}
        engine.finishPresenting()

        _ = engine.submitResponse([99])
        engine.advanceAfterFeedback()

        #expect(engine.isComplete)
    }
}

