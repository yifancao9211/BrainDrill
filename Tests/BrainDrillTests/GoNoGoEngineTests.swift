import Foundation
import Testing
@testable import BrainDrill

struct GoNoGoEngineTests {
    @Test func generatesCorrectTrialRatio() {
        let config = GoNoGoSessionConfig(trialsPerBlock: 40, blockCount: 1, goRatio: 0.75)
        let engine = GoNoGoEngine(config: config)
        let goCount = engine.trials.filter { $0.stimulusType == .go }.count
        #expect(goCount == 30)
        #expect(engine.trials.count == 40)
    }

    @Test func dPrimeIsComputed() {
        let config = GoNoGoSessionConfig(trialsPerBlock: 20, blockCount: 1)
        let engine = GoNoGoEngine(config: config)

        for trial in engine.trials {
            engine.showStimulus()
            if trial.stimulusType == .go {
                _ = engine.recordTap(at: Date())
            } else {
                engine.recordTimeout()
            }
            engine.advanceToNext()
        }

        let m = engine.computeMetrics()
        #expect(m.dPrime > 0)
        #expect(m.goAccuracy > 0.99)
        #expect(m.noGoAccuracy > 0.99)
    }
}
