import Foundation
import Testing
@testable import BrainDrill

struct ChoiceRTFlowTests {
    @Test func fullSessionFlow() {
        let config = ChoiceRTSessionConfig(choiceCount: 2, trialsPerBlock: 5, blockCount: 1)
        let engine = ChoiceRTEngine(config: config)

        #expect(engine.phase == .idle)
        engine.beginTrial()
        #expect(engine.phase == .fixation)
        engine.showStimulus()
        #expect(engine.phase == .stimulus)

        let trial = engine.currentTrial!
        let onset = engine.stimulusOnsetTime!
        let result = engine.recordResponse(trial.correctResponseIndex, at: onset.addingTimeInterval(0.35))
        #expect(result != nil)
        if case .feedback(let correct) = engine.phase {
            #expect(correct == true)
        } else {
            Issue.record("Expected feedback phase")
        }

        engine.advanceToNext()
        #expect(engine.phase == .iti || engine.phase == .completed)
    }

    @Test func completeAllTrials() {
        let config = ChoiceRTSessionConfig(choiceCount: 2, trialsPerBlock: 5, blockCount: 1)
        let engine = ChoiceRTEngine(config: config)

        for _ in 0..<5 {
            engine.beginTrial()
            engine.showStimulus()
            let trial = engine.currentTrial!
            let onset = engine.stimulusOnsetTime!
            _ = engine.recordResponse(trial.correctResponseIndex, at: onset.addingTimeInterval(0.3))
            engine.advanceToNext()
        }

        #expect(engine.isComplete)
        let m = engine.computeMetrics()
        #expect(m.accuracy > 0.99)
        #expect(m.medianRT > 0.2)
    }
}

struct GoNoGoFlowTests {
    @Test func fullSessionFlow() {
        let config = GoNoGoSessionConfig(trialsPerBlock: 10, blockCount: 1)
        let engine = GoNoGoEngine(config: config)

        #expect(engine.phase == .idle)
        engine.beginTrial()
        #expect(engine.phase == .fixation)
        engine.showStimulus()
        #expect(engine.phase == .stimulus)

        if engine.currentTrial!.stimulusType == .go {
            _ = engine.recordTap(at: Date())
        } else {
            engine.recordTimeout()
        }

        if case .feedback = engine.phase {} else {
            Issue.record("Expected feedback phase after response")
        }

        engine.advanceToNext()
    }

    @Test func completeAllTrials() {
        let config = GoNoGoSessionConfig(trialsPerBlock: 10, blockCount: 1)
        let engine = GoNoGoEngine(config: config)

        for trial in engine.trials {
            engine.beginTrial()
            engine.showStimulus()
            if trial.stimulusType == .go {
                _ = engine.recordTap(at: Date())
            } else {
                engine.recordTimeout()
            }
            engine.advanceToNext()
        }

        #expect(engine.isComplete)
        let m = engine.computeMetrics()
        #expect(m.dPrime > 0)
    }
}

struct FlankerFlowTests {
    @Test func fullSessionFlow() {
        let config = FlankerSessionConfig(trialsPerBlock: 5, blockCount: 1)
        let engine = FlankerEngine(config: config)

        engine.beginTrial()
        #expect(engine.phase == .fixation)
        engine.showStimulus()
        #expect(engine.phase == .stimulus)

        let trial = engine.currentTrial!
        _ = engine.recordResponse(trial.targetDirection, at: Date())
        if case .feedback(let correct) = engine.phase {
            #expect(correct)
        } else {
            Issue.record("Expected feedback")
        }

        engine.advanceToNext()
    }

    @Test func completeAllTrials() {
        let config = FlankerSessionConfig(trialsPerBlock: 4, blockCount: 1)
        let engine = FlankerEngine(config: config)

        for trial in engine.trials {
            engine.beginTrial()
            engine.showStimulus()
            _ = engine.recordResponse(trial.targetDirection, at: Date())
            engine.advanceToNext()
        }

        #expect(engine.isComplete)
    }
}

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

struct VisualSearchFlowTests {
    @Test func fullSessionFlow() {
        let config = VisualSearchSessionConfig(setSizes: [8], trialsPerSize: 3)
        let engine = VisualSearchEngine(config: config)

        engine.beginTrial()
        #expect(engine.phase == .fixation)

        engine.showDisplay()
        #expect(engine.phase == .display)

        let trial = engine.currentTrial!
        let result = engine.recordResponse(userSaidPresent: trial.targetPresent)
        #expect(result?.correct == true)

        engine.advanceToNext()
    }

    @Test func completeAllTrials() {
        let config = VisualSearchSessionConfig(setSizes: [8], trialsPerSize: 3)
        let engine = VisualSearchEngine(config: config)

        for trial in engine.trials {
            engine.beginTrial()
            engine.showDisplay()
            _ = engine.recordResponse(userSaidPresent: trial.targetPresent)
            engine.advanceToNext()
        }

        #expect(engine.isComplete)
    }
}

struct StopSignalFlowTests {
    @Test func goTrialFlow() {
        let config = StopSignalSessionConfig(trialsPerBlock: 5, blockCount: 1, stopRatio: 0.0)
        let engine = StopSignalEngine(config: config)

        engine.beginTrial()
        #expect(engine.phase == .fixation)

        engine.showStimulus()
        #expect(engine.phase == .stimulus)

        let trial = engine.currentTrial!
        let onset = engine.stimulusOnsetTime!
        let result = engine.recordResponse(trial.correctDirection, at: onset.addingTimeInterval(0.35))
        #expect(result?.correct == true)
        #expect(result?.inhibited == false)
    }

    @Test func stopTrialInhibitFlow() {
        let config = StopSignalSessionConfig(trialsPerBlock: 5, blockCount: 1, stopRatio: 1.0)
        let engine = StopSignalEngine(config: config)

        engine.beginTrial()
        engine.showStimulus()
        engine.showStopSignal()
        #expect(engine.phase == .stopSignalShown)

        engine.recordStopTimeout()
        if case .feedback(let correct) = engine.phase {
            #expect(correct)
        }
    }

    @Test func completeAllTrials() {
        let config = StopSignalSessionConfig(trialsPerBlock: 5, blockCount: 1, stopRatio: 0.2)
        let engine = StopSignalEngine(config: config)

        for trial in engine.trials {
            engine.beginTrial()
            engine.showStimulus()
            if trial.hasStopSignal {
                engine.showStopSignal()
                engine.recordStopTimeout()
            } else {
                _ = engine.recordResponse(trial.correctDirection, at: Date().addingTimeInterval(0.3))
            }
            engine.advanceToNext()
        }

        #expect(engine.isComplete)
        let m = engine.computeMetrics()
        #expect(m.totalTrials == 5)
    }
}

struct NBackFlowTests {
    @Test func stimulusPhaseFlow() {
        let config = NBackSessionConfig(startingN: 1, trialsPerBlock: 5, blockCount: 1)
        let engine = NBackEngine(config: config)

        engine.showStimulus()
        #expect(engine.phase == .stimulus)
        #expect(engine.currentStimulus != nil)

        engine.enterISI()
        #expect(engine.phase == .isi)

        engine.advanceToNext()
    }

    @Test func matchResponseFlow() {
        let config = NBackSessionConfig(startingN: 1, trialsPerBlock: 10, blockCount: 1)
        let engine = NBackEngine(config: config)

        for i in 0..<engine.sequence.count {
            engine.showStimulus()
            if i >= engine.currentN && engine.isTarget {
                let result = engine.recordMatch(at: Date())
                #expect(result != nil)
                #expect(result?.isTarget == true)
            }
            engine.enterISI()
            engine.advanceToNext()
        }

        #expect(engine.isComplete)
        let m = engine.computeMetrics()
        #expect(m.hitRate > 0)
    }
}

struct DigitSpanFlowTests {
    @Test func presentRecallFlow() {
        let config = DigitSpanSessionConfig(startingLength: 3, mode: .forward, consecutiveWrongToDemote: 1)
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

    @Test func wrongAnswerEndsSession() {
        let config = DigitSpanSessionConfig(startingLength: 3, mode: .forward, consecutiveWrongToDemote: 1)
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
        let config = CorsiBlockSessionConfig(startingLength: 3, consecutiveWrongToDemote: 1)
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

    @Test func wrongAnswerEndsSession() {
        let config = CorsiBlockSessionConfig(startingLength: 3, consecutiveWrongToDemote: 1)
        let engine = CorsiBlockEngine(config: config)

        engine.beginNextTrial()
        while engine.advancePresentingBlock() {}
        engine.finishPresenting()

        _ = engine.submitResponse([99])
        engine.advanceAfterFeedback()

        #expect(engine.isComplete)
    }
}

struct CoordinatorFlowTests {
    @Test func choiceRTCoordinatorFullCycle() {
        let coord = ChoiceRTCoordinator()
        coord.startSession(settings: .default)
        #expect(coord.isActive)
        #expect(coord.engine != nil)

        let engine = coord.engine!
        for _ in 0..<engine.trials.count {
            engine.beginTrial()
            engine.showStimulus()
            let trial = engine.currentTrial!
            let onset = engine.stimulusOnsetTime!
            _ = coord.handleResponse(trial.correctResponseIndex, at: onset.addingTimeInterval(0.3))
        }

        #expect(coord.lastResult != nil)
        #expect(coord.lastResult?.module == .choiceRT)
    }

    @Test func goNoGoCoordinatorFullCycle() {
        let coord = GoNoGoCoordinator()
        coord.startSession(settings: .default)

        let engine = coord.engine!
        for trial in engine.trials {
            engine.beginTrial()
            engine.showStimulus()
            if trial.stimulusType == .go {
                _ = coord.handleTap(at: Date())
            } else {
                engine.recordTimeout()
                engine.advanceToNext()
            }
        }

        #expect(coord.engine == nil || coord.lastResult != nil)
    }

    @Test func flankerCoordinatorFullCycle() {
        let coord = FlankerCoordinator()
        coord.startSession(settings: .default)

        let engine = coord.engine!
        for trial in engine.trials {
            engine.beginTrial()
            engine.showStimulus()
            _ = coord.handleResponse(trial.targetDirection, at: Date())
        }

        #expect(coord.lastResult != nil)
    }
}
