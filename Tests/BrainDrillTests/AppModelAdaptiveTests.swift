import Foundation
import Testing
@testable import BrainDrill

@MainActor
struct AppModelAdaptiveTests {
    @Test
    func schulteSessionAutoPromotesRecommendedDifficulty() {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LocalTrainingStore(baseURL: tempRoot)
        let appModel = AppModel(store: store)

        appModel.settings.adaptiveDifficultyEnabled = true
        appModel.settings.preferredDifficulty = .easy3x3
        appModel.settings.adaptiveConfig = AdaptiveDifficulty.Config(
            windowSize: 1,
            promoteThreshold: 0.1,
            demoteThreshold: 0.0,
            stabilityCV: 1.0
        )
        appModel.settings.schulteSetRep = SchulteSetRepConfig(
            setsPerSession: 1,
            repsPerSet: 1,
            restBetweenRepsSec: 0,
            restBetweenSetsSec: 0
        )

        appModel.startSchulteSession()
        for number in 1...9 {
            appModel.handleSchulteTileTap(number)
        }

        #expect(appModel.settings.preferredDifficulty == .focus4x4)
        #expect(appModel.adaptiveState(for: .schulte).recommendedStartLevel == 2)
        #expect(appModel.schulte.lastCompletedSummary != nil)
    }
}
