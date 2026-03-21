import Foundation
import Testing
@testable import BrainDrill

struct StopSignalEngineTests {
    @Test func generatesCorrectTrialCount() {
        let config = StopSignalSessionConfig(trialsPerBlock: 40, blockCount: 1, stopRatio: 0.25)
        let engine = StopSignalEngine(config: config)
        #expect(engine.trials.count == 40)
    }

    @Test func stopTrialRatioCorrect() {
        let config = StopSignalSessionConfig(trialsPerBlock: 40, blockCount: 1, stopRatio: 0.25)
        let engine = StopSignalEngine(config: config)
        let stopCount = engine.trials.filter { $0.hasStopSignal }.count
        #expect(stopCount == 10)
    }

    @Test func goTrialCorrectResponse() {
        let config = StopSignalSessionConfig(trialsPerBlock: 10, blockCount: 1, stopRatio: 0.0)
        let engine = StopSignalEngine(config: config)

        engine.beginTrial()
        engine.showStimulus()
        let trial = engine.currentTrial!
        #expect(!trial.hasStopSignal)
        let onset = engine.stimulusOnsetTime!
        let result = engine.recordResponse(trial.correctDirection, at: onset.addingTimeInterval(0.35))
        #expect(result?.correct == true)
    }

    @Test func stopTrialInhibitionSuccess() {
        let config = StopSignalSessionConfig(trialsPerBlock: 10, blockCount: 1, stopRatio: 1.0, initialSSD: 200)
        let engine = StopSignalEngine(config: config)

        engine.beginTrial()
        engine.showStimulus()
        engine.showStopSignal()
        engine.recordStopTimeout()

        #expect(engine.results.count == 1)
        #expect(engine.results.first?.inhibited == true)
    }

    @Test func stopTrialInhibitionFailure() {
        let config = StopSignalSessionConfig(trialsPerBlock: 10, blockCount: 1, stopRatio: 1.0, initialSSD: 200)
        let engine = StopSignalEngine(config: config)

        engine.beginTrial()
        engine.showStimulus()
        engine.showStopSignal()
        let onset = engine.stimulusOnsetTime!
        let result = engine.recordResponse(.left, at: onset.addingTimeInterval(0.35))
        #expect(result?.inhibited == false)
    }

    @Test func ssdAdjustsWithStaircase() {
        let config = StopSignalSessionConfig(trialsPerBlock: 10, blockCount: 1, stopRatio: 1.0, initialSSD: 200, ssdStepMs: 50)
        let engine = StopSignalEngine(config: config)

        let initialSSD = engine.currentSSD

        engine.beginTrial()
        engine.showStimulus()
        engine.showStopSignal()
        engine.recordStopTimeout()
        engine.advanceToNext()

        #expect(engine.currentSSD == initialSSD + 50)
    }

    @Test func ssrtComputed() {
        let config = StopSignalSessionConfig(trialsPerBlock: 20, blockCount: 1, stopRatio: 0.25)
        let engine = StopSignalEngine(config: config)

        for trial in engine.trials {
            engine.beginTrial()
            engine.showStimulus()
            let onset = engine.stimulusOnsetTime!

            if trial.hasStopSignal {
                engine.showStopSignal()
                engine.recordStopTimeout()
            } else {
                _ = engine.recordResponse(trial.correctDirection, at: onset.addingTimeInterval(0.40))
            }
            engine.advanceToNext()
        }

        let m = engine.computeMetrics()
        #expect(m.totalTrials == 20)
        #expect(m.ssrt > 0)
        #expect(m.goRT > 0)
        #expect(m.inhibitionRate > 0.5)
    }

    @Test func completesAfterAllTrials() {
        let config = StopSignalSessionConfig(trialsPerBlock: 5, blockCount: 1, stopRatio: 0.0)
        let engine = StopSignalEngine(config: config)

        for trial in engine.trials {
            engine.beginTrial()
            engine.showStimulus()
            _ = engine.recordResponse(trial.correctDirection)
            engine.advanceToNext()
        }

        #expect(engine.isComplete)
    }
}
