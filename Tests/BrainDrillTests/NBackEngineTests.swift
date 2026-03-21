import Foundation
import Testing
@testable import BrainDrill

struct NBackEngineTests {
    @Test func generatesCorrectSequenceLength() {
        let config = NBackSessionConfig(startingN: 2, trialsPerBlock: 20, blockCount: 1)
        let engine = NBackEngine(config: config)
        #expect(engine.sequence.count == 22) // 20 + N
    }

    @Test func sequenceContainsTargets() {
        let config = NBackSessionConfig(startingN: 1, trialsPerBlock: 20, blockCount: 1, targetRatio: 0.30)
        let engine = NBackEngine(config: config)
        var targetCount = 0
        for i in config.startingN..<engine.sequence.count {
            if engine.sequence[i] == engine.sequence[i - config.startingN] {
                targetCount += 1
            }
        }
        #expect(targetCount >= 3)
    }

    @Test func dPrimeComputedCorrectly() {
        let config = NBackSessionConfig(startingN: 1, trialsPerBlock: 10, blockCount: 1)
        let engine = NBackEngine(config: config)

        for i in 0..<engine.sequence.count {
            engine.showStimulus()
            if i >= engine.currentN && engine.isTarget {
                _ = engine.recordMatch(at: Date())
            }
            engine.enterISI()
            engine.advanceToNext()
        }

        let m = engine.computeMetrics()
        #expect(m.hitRate > 0.5)
        #expect(m.dPrime > 0)
    }
}
