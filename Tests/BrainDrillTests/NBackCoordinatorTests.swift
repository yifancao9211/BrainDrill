import Foundation
import Testing
@testable import BrainDrill

struct NBackCoordinatorTests {
    @Test func recordingMatchKeepsCurrentTrialRhythm() {
        var settings = TrainingSettings.default
        settings.nBackStartingN = 1
        settings.nBackStimulusDurationMs = 900
        settings.nBackISIMs = 1800

        let coordinator = NBackCoordinator()
        coordinator.startSession(settings: settings)

        guard let engine = coordinator.engine else {
            Issue.record("Engine should exist after starting N-Back session.")
            return
        }

        engine.showStimulus()
        let trialIndexBeforeResponse = engine.currentTrialIndex

        _ = coordinator.handleMatch(at: Date())

        #expect(engine.phase == .stimulus)
        #expect(engine.currentTrialIndex == trialIndexBeforeResponse)
        #expect(engine.respondedThisTrial)
    }
}
