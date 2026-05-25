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
}
