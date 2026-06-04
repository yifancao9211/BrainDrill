import Testing
@testable import BrainDrill

struct SyllogismEngineTests {
    @Test func formalTrainingAvoidsExactRepeatsWithinSession() {
        let engine = SyllogismEngine(difficulty: 1)
        var fingerprints: Set<String> = []

        while !engine.isComplete {
            engine.beginNextTrial()
            guard let trial = engine.currentTrial else {
                break
            }

            #expect(!fingerprints.contains(trial.repetitionFingerprint))
            fingerprints.insert(trial.repetitionFingerprint)

            engine.recordResponse(userSaysValid: trial.isValid)
            engine.advanceToNext()
        }

        #expect(fingerprints.count == engine.totalTrials)
    }

    @Test func trainingAvoidsRecentlySeenItemsAcrossSessions() {
        func runSession(seen: [String]) -> [String] {
            let engine = SyllogismEngine(difficulty: 1, totalTrials: 3, seenFingerprints: seen)
            while !engine.isComplete {
                engine.beginNextTrial()
                guard let trial = engine.currentTrial else { break }
                engine.recordResponse(userSaysValid: trial.isValid)
                engine.advanceToNext()
            }
            return engine.generatedFingerprints
        }

        // First session has no history; the second is seeded with the first's
        // items and must produce entirely different ones (the diff-1 pool is
        // comfortably larger than these two short sessions combined).
        let first = runSession(seen: [])
        #expect(first.count == 3)

        let second = runSession(seen: first)
        #expect(second.count == 3)
        #expect(Set(first).isDisjoint(with: Set(second)))
    }
}
