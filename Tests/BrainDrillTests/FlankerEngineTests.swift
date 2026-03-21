import Foundation
import Testing
@testable import BrainDrill

struct FlankerEngineTests {
    @Test func generatesCorrectTrialCount() {
        let config = FlankerSessionConfig(trialsPerBlock: 40, blockCount: 2)
        let engine = FlankerEngine(config: config)
        #expect(engine.trials.count == 80)
    }

    @Test func halfCongruentHalfIncongruent() {
        let config = FlankerSessionConfig(trialsPerBlock: 20, blockCount: 2)
        let engine = FlankerEngine(config: config)
        let congruent = engine.trials.filter { $0.type == .congruent }.count
        let incongruent = engine.trials.filter { $0.type == .incongruent }.count
        #expect(congruent == 20)
        #expect(incongruent == 20)
    }

    @Test func metricsComputeConflictCost() {
        let config = FlankerSessionConfig(trialsPerBlock: 4, blockCount: 1)
        let engine = FlankerEngine(config: config)
        engine.beginTrial()
        engine.showStimulus()

        for trial in engine.trials {
            engine.showStimulus()
            _ = engine.recordResponse(trial.targetDirection, at: Date())
            engine.advanceToNext()
        }

        let m = engine.computeMetrics()
        #expect(m.totalTrials == 4)
        #expect(m.accuracy > 0.99)
    }
}
