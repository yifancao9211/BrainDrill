import Foundation
import Testing
@testable import BrainDrill

@MainActor
struct AppModelFeedbackTests {
    @Test
    func visualSearchFeedbackUsesLatestAccuracyAndErrorRate() {
        let store = LocalTrainingStore(baseURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let appModel = AppModel(store: store)
        let now = Date()

        appModel.sessions = [
            SessionResult(
                module: .visualSearch,
                startedAt: now.addingTimeInterval(-60),
                endedAt: now,
                duration: 60,
                metrics: .visualSearch(VisualSearchMetrics(
                    totalTrials: 16,
                    accuracy: 0.92,
                    searchSlope: 0.08,
                    presentRT: 0.62,
                    absentRT: 0.74,
                    setSizeRTs: [8: 0.61, 16: 0.75],
                    errorRate: 0.08
                ))
            )
        ]

        #expect(appModel.feedbackStatus(for: .visualSearch) == .success)
    }

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
                module: .choiceRT,
                startedAt: now.addingTimeInterval(-60),
                endedAt: now,
                duration: 60,
                metrics: .choiceRT(ChoiceRTMetrics(
                    totalTrials: 24,
                    medianRT: 0.41,
                    rtStandardDeviation: 0.05,
                    accuracy: 0.96,
                    postErrorSlowing: 0.02,
                    anticipationCount: 0,
                    choiceCount: 3
                ))
            ),
            SessionResult(
                module: .flanker,
                startedAt: now.addingTimeInterval(-120),
                endedAt: now.addingTimeInterval(-90),
                duration: 30,
                metrics: .flanker(FlankerMetrics(
                    totalTrials: 24,
                    congruentRT: 0.45,
                    incongruentRT: 0.82,
                    conflictCost: 0.37,
                    accuracy: 0.62,
                    stimulusDurationMs: 200
                ))
            ),
        ]

        #expect(appModel.feedbackStatus(for: .choiceRT) == .success)
        #expect(appModel.feedbackStatus(for: .flanker) == .error)
    }
}
