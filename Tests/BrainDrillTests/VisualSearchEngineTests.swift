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
        for trial in engine.trials {
            for item in trial.items {
                let matchShape = item.shape == trial.target.shape
                let matchColor = item.color == trial.target.color
                if matchShape && matchColor { continue }
                let sharedFeatures = (matchShape ? 1 : 0) + (matchColor ? 1 : 0)
                #expect(sharedFeatures == 1, "Distractor should share exactly one feature")
            }
        }
    }

    @Test func eachTrialHasAtMostOneExactTargetMatch() {
        let config = VisualSearchSessionConfig(setSizes: [8, 16, 24], trialsPerSize: 12)
        let engine = VisualSearchEngine(config: config)

        for trial in engine.trials {
            let exactMatches = trial.items.filter {
                $0.shape == trial.target.shape && $0.color == trial.target.color
            }
            #expect(exactMatches.count == (trial.targetPresent ? 1 : 0))
        }
    }

    @Test func correctResponseRecorded() {
        let config = VisualSearchSessionConfig(setSizes: [8], trialsPerSize: 3)
        let engine = VisualSearchEngine(config: config)

        engine.beginTrial()
        engine.showDisplay()
        let trial = engine.currentTrial!
        let result = engine.recordResponse(userSaidPresent: trial.targetPresent, selectedItemID: selectedItemID(for: trial))
        #expect(result?.correct == true)
    }

    @Test func foundResponseRequiresSelectedTarget() {
        let config = VisualSearchSessionConfig(setSizes: [8], trialsPerSize: 3, targetPresentRatio: 1.0)
        let engine = VisualSearchEngine(config: config)

        engine.beginTrial()
        engine.showDisplay()
        let result = engine.recordResponse(userSaidPresent: true)

        #expect(result?.correct == false)
    }

    @Test func supportsMoreColorsAndShapes() {
        #expect(SearchShape.allCases.count >= 8)
        #expect(SearchColor.allCases.count >= 7)
        #expect(SearchColor.allCases.contains(.blue))
        #expect(SearchColor.allCases.contains(.green))
        #expect(SearchColor.allCases.contains(.purple))
    }

    @Test func eachSearchFieldMixesMovingAndStaticItems() {
        let config = VisualSearchSessionConfig(setSizes: [8, 16], trialsPerSize: 4)
        let engine = VisualSearchEngine(config: config)

        for trial in engine.trials {
            #expect(trial.items.contains { $0.spinDegreesPerSecond == 0 })
            #expect(trial.items.contains { $0.spinDegreesPerSecond != 0 })
        }
    }

    @Test func completesAfterAllTrials() {
        let config = VisualSearchSessionConfig(setSizes: [8], trialsPerSize: 3)
        let engine = VisualSearchEngine(config: config)

        for trial in engine.trials {
            engine.showDisplay()
            _ = engine.recordResponse(userSaidPresent: trial.targetPresent, selectedItemID: selectedItemID(for: trial))
            engine.advanceToNext()
        }

        #expect(engine.isComplete)
    }

    @Test func metricsComputeSearchSlope() {
        let config = VisualSearchSessionConfig(setSizes: [8, 16, 24], trialsPerSize: 4)
        let engine = VisualSearchEngine(config: config)

        for trial in engine.trials {
            engine.showDisplay()
            _ = engine.recordResponse(userSaidPresent: trial.targetPresent, selectedItemID: selectedItemID(for: trial))
            engine.advanceToNext()
        }

        let m = engine.computeMetrics()
        #expect(m.totalTrials == 12)
        #expect(m.accuracy > 0.5)
        #expect(!m.setSizeRTs.isEmpty)
    }

    private func selectedItemID(for trial: VisualSearchTrial) -> Int? {
        trial.targetPresent ? trial.targetItem?.id : nil
    }
}
