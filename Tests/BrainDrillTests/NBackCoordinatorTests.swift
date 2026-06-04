import Foundation
import Testing
@testable import BrainDrill

struct NBackCoordinatorTests {
    @Test func startSessionWaitsIdleForAutoPacedDriver() {
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

        // The view's schedulePhase driver advances from .idle; the session does not
        // auto-present a stimulus on creation.
        #expect(engine.phase == .idle)
        #expect(coordinator.isActive)
    }

    @Test func matchRecordsResponseOnScoredTrial() {
        var settings = TrainingSettings.default
        settings.nBackStartingN = 1

        let coordinator = NBackCoordinator()
        coordinator.startSession(settings: settings)

        guard let engine = coordinator.engine else {
            Issue.record("Engine should exist after starting N-Back session.")
            return
        }

        // Trial 0 is observation-only: a match press is ignored.
        engine.beginTrial()
        coordinator.handleMatch(at: Date())
        #expect(!engine.respondedThisTrial)

        // Advance to the first scored trial, where a press is registered.
        engine.enterISI()
        engine.advanceTrial()
        coordinator.handleMatch(at: Date())
        #expect(engine.respondedThisTrial)
    }
}
