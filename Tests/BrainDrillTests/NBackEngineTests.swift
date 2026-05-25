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

        while !engine.isComplete {
            if engine.phase == .idle {
                engine.advanceByUser()
            }
            _ = engine.recordResponse(isMatch: engine.isTarget, at: Date())
        }

        let m = engine.computeMetrics()
        #expect(m.hitRate > 0.5)
        #expect(m.dPrime > 0)
    }

    @Test func userPacedAdvanceRecordsDecisionInterval() {
        let config = NBackSessionConfig(startingN: 1, trialsPerBlock: 3, blockCount: 1)
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let engine = NBackEngine(config: config, startedAt: startedAt)

        engine.advanceByUser(at: startedAt)
        _ = engine.recordNonMatch(at: startedAt.addingTimeInterval(1.25))
        _ = engine.recordResponse(isMatch: engine.isTarget, at: startedAt.addingTimeInterval(3.25))

        #expect(engine.results.first?.decisionInterval == 2.0)
        #expect(engine.computeMetrics().averageDecisionInterval == 2.0)
    }
}
