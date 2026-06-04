import Foundation
import Testing
@testable import BrainDrill

@MainActor
struct AppModelFeedbackTests {
    @Test
    func nBackFeedbackFlagsWeakRunsAsError() {
        let store = LocalTrainingStore(baseURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let appModel = AppModel(store: store)
        let now = Date()

        appModel.sessions = [
            SessionResult(
                module: .nBack,
                startedAt: now.addingTimeInterval(-90),
                endedAt: now,
                duration: 90,
                metrics: .nBack(NBackMetrics(
                    nLevel: 2,
                    totalTrials: 24,
                    hitRate: 0.42,
                    falseAlarmRate: 0.35,
                    dPrime: 0.21
                ))
            )
        ]

        #expect(appModel.feedbackStatus(for: .nBack) == .error)
    }

    @Test
    func supportModuleFeedbackUsesRecordedMetrics() {
        let store = LocalTrainingStore(baseURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let appModel = AppModel(store: store)
        let now = Date()

        appModel.sessions = [
            SessionResult(
                module: .changeDetection,
                startedAt: now.addingTimeInterval(-60),
                endedAt: now,
                duration: 60,
                metrics: .changeDetection(ChangeDetectionMetrics(
                    totalTrials: 24,
                    accuracy: 0.92,
                    dPrime: 2.4,
                    hitRate: 0.95,
                    falseAlarmRate: 0.10,
                    maxSetSize: 5,
                    averageRT: 0.5
                ))
            ),
        ]

        #expect(appModel.feedbackStatus(for: .changeDetection) == .success)
    }
}
