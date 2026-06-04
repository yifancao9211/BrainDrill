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

        // Perfect performer: press "match" on every target, never on a non-target.
        while !engine.isComplete {
            switch engine.phase {
            case .idle:
                engine.beginTrial()
            case .stimulus:
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

        let m = engine.computeMetrics()
        #expect(m.hitRate > 0.5)
        #expect(m.dPrime > 0)
    }

    @Test func practiceBlockRunsUnscoredThenStartsScoredBlock() {
        let config = NBackSessionConfig(startingN: 1, trialsPerBlock: 8, blockCount: 1, practiceTrials: 3)
        let engine = NBackEngine(config: config)

        #expect(engine.isPractice)

        // Play the entire practice block.
        engine.beginTrial()
        var sawPracticeComplete = false
        while !engine.isComplete {
            switch engine.phase {
            case .idle:
                engine.beginTrial()
            case .stimulus:
                if engine.currentTrialIndex >= engine.currentN && engine.isTarget {
                    engine.recordMatch(at: Date())
                }
                engine.enterISI()
            case .isi:
                engine.advanceTrial()
            case .practiceComplete:
                // Practice produced no scored results.
                sawPracticeComplete = true
                #expect(!engine.isPractice)
                #expect(engine.results.isEmpty)
                engine.beginTrial() // begin the scored block
            case .blockBreak, .completed:
                break
            }
        }

        #expect(sawPracticeComplete)
        let metrics = engine.computeMetrics()
        #expect(metrics.totalTrials > 0) // only the scored block counts
    }

    @Test func observationTrialsRejectResponses() {
        let config = NBackSessionConfig(startingN: 2, trialsPerBlock: 5, blockCount: 1)
        let engine = NBackEngine(config: config)

        engine.beginTrial()
        // Trial 0 is part of the leading N-digit build-up: no response is possible.
        #expect(engine.isObservationOnly)
        engine.recordMatch(at: Date())
        #expect(!engine.respondedThisTrial)
    }

    @Test func recordsReactionTimeForResponses() {
        let config = NBackSessionConfig(startingN: 1, trialsPerBlock: 3, blockCount: 1)
        let t0 = Date(timeIntervalSince1970: 1_000)
        let engine = NBackEngine(config: config, startedAt: t0)

        // Trial 0: observation (index 0 < N).
        engine.beginTrial(at: t0)
        #expect(engine.isObservationOnly)
        engine.enterISI()
        engine.advanceTrial(at: t0) // -> trial 1, stimulus onset = t0

        // Trial 1: press "match" 0.5s after onset.
        #expect(!engine.isObservationOnly)
        engine.recordMatch(at: t0.addingTimeInterval(0.5))
        engine.enterISI()
        engine.advanceTrial(at: t0.addingTimeInterval(2.0)) // closes trial 1

        let scored = engine.results.first { $0.trialIndex == 1 }
        #expect(scored?.responded == true)
        #expect(scored?.reactionTime == 0.5)
    }
}
