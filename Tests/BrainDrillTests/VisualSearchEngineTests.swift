import Foundation
import Testing
@testable import BrainDrill

struct VisualSearchEngineTests {
    @Test func generatesCorrectTrialCount() {
        let config = VisualSearchSessionConfig(setSizes: [8, 16], trialsPerSize: 5)
        let engine = VisualSearchEngine(config: config)
        #expect(engine.trials.count == 10)
    }

    @Test func trialsContainAllSetSizes() {
        let config = VisualSearchSessionConfig(setSizes: [8, 16, 24], trialsPerSize: 4)
        let engine = VisualSearchEngine(config: config)
        let sizes = Set(engine.trials.map(\.setSize))
        #expect(sizes == [8, 16, 24])
    }

    @Test func trialHasCorrectItemCount() {
        let config = VisualSearchSessionConfig(setSizes: [12], trialsPerSize: 3)
        let engine = VisualSearchEngine(config: config)
        for trial in engine.trials {
            #expect(trial.items.count == 12)
        }
    }

    @Test func distractorsShareExactlyOneFeatureWithTarget() {
        let config = VisualSearchSessionConfig(setSizes: [8], trialsPerSize: 5, targetPresentRatio: 1.0)
        let engine = VisualSearchEngine(config: config)
        let target = engine.target

        for trial in engine.trials {
            for item in trial.items {
                let matchShape = item.shape == target.shape
                let matchColor = item.color == target.color
                if matchShape && matchColor { continue }
                let sharedFeatures = (matchShape ? 1 : 0) + (matchColor ? 1 : 0)
                #expect(sharedFeatures == 1, "Distractor should share exactly one feature")
            }
        }
    }

    @Test func correctResponseRecorded() {
        let config = VisualSearchSessionConfig(setSizes: [8], trialsPerSize: 3)
        let engine = VisualSearchEngine(config: config)

        engine.beginTrial()
        engine.showDisplay()
        let trial = engine.currentTrial!
        let result = engine.recordResponse(userSaidPresent: trial.targetPresent)
        #expect(result?.correct == true)
    }

    @Test func completesAfterAllTrials() {
        let config = VisualSearchSessionConfig(setSizes: [8], trialsPerSize: 3)
        let engine = VisualSearchEngine(config: config)

        for trial in engine.trials {
            engine.showDisplay()
            _ = engine.recordResponse(userSaidPresent: trial.targetPresent)
            engine.advanceToNext()
        }

        #expect(engine.isComplete)
    }

    @Test func metricsComputeSearchSlope() {
        let config = VisualSearchSessionConfig(setSizes: [8, 16, 24], trialsPerSize: 4)
        let engine = VisualSearchEngine(config: config)

        for trial in engine.trials {
            engine.showDisplay()
            _ = engine.recordResponse(userSaidPresent: trial.targetPresent)
            engine.advanceToNext()
        }

        let m = engine.computeMetrics()
        #expect(m.totalTrials == 12)
        #expect(m.accuracy > 0.5)
        #expect(!m.setSizeRTs.isEmpty)
    }
}
