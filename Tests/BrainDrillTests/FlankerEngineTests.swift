import Foundation
import Testing
@testable import BrainDrill

struct FlankerEngineTests {
    @Test func engineInitializes() {
        let config = FlankerSessionConfig(trialsPerBlock: 40, blockCount: 2)
        let engine = FlankerEngine(config: config)
        #expect(engine.currentTrialIndex == 0)
        #expect(engine.phase == .idle)
    }

    @Test func trialGenerationAndResponse() {
        let config = FlankerSessionConfig(trialsPerBlock: 4, blockCount: 1)
        let engine = FlankerEngine(config: config)

        for _ in 0..<4 {
            engine.beginTrial()
            engine.showStimulus()
            guard let trial = engine.currentTrial else {
                Issue.record("currentTrial should not be nil during stimulus")
                return
            }
            _ = engine.recordResponse(trial.targetDirection, at: Date())
            engine.advanceToNext()
        }

        let m = engine.computeMetrics()
        #expect(m.totalTrials == 4)
        #expect(m.accuracy > 0.99)
    }
}
