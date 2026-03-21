import Foundation
import Observation

@Observable
final class AppModel {
    var selectedRoute: AppRoute = .training
    var settings: TrainingSettings
    var history: [SchulteSessionResult]
    var activeEngine: SchulteEngine?
    var statusMessage: String
    var lastCompletedSummary: CompletedSessionSummary?
    var lastPersistenceError: String?

    @ObservationIgnored private let store: any TrainingStore

    init(store: any TrainingStore) {
        self.store = store
        self.settings = (try? store.loadSettings()) ?? .default
        self.history = ((try? store.loadResults()) ?? []).sorted { $0.endedAt > $1.endedAt }
        self.statusMessage = "选择难度后开始一轮舒尔特训练。"
    }

    var statistics: TrainingStatistics {
        TrainingStatistics(results: history)
    }

    var recentResults: [SchulteSessionResult] {
        Array(history.prefix(8))
    }

    var storageLocationDescription: String {
        store.storageURL.path
    }

    var isTrainingActive: Bool {
        activeEngine != nil
    }

    func startSession() {
        let config = SchulteSessionConfig(
            difficulty: settings.preferredDifficulty,
            showHints: settings.showHints,
            startMode: .manual
        )

        activeEngine = SchulteEngine(config: config)
        lastCompletedSummary = nil
        selectedRoute = .training
        statusMessage = "按顺序点击 1 到 \(config.difficulty.totalTiles)。"
    }

    func cancelSession() {
        activeEngine = nil
        statusMessage = "已取消当前训练。"
    }

    func handleTileTap(_ number: Int, at date: Date = Date()) {
        guard let activeEngine else { return }

        switch activeEngine.handleTap(number, at: date) {
        case let .correct(nextNumber):
            statusMessage = "正确，继续找 \(nextNumber)。"
        case let .incorrect(expected):
            statusMessage = "当前应点击 \(expected)。"
        case let .completed(result):
            history.insert(result, at: 0)
            history.sort { $0.endedAt > $1.endedAt }
            persistResults()
            let summary = CompletedSessionSummary(result: result, historyAfterSave: history)
            lastCompletedSummary = summary
            self.activeEngine = nil
            statusMessage = summary.didSetPersonalBest ? "刷新个人最佳。" : "本轮训练已完成。"
            selectedRoute = .statistics
        case .ignored:
            break
        }
    }

    func updateShowHints(_ isEnabled: Bool) {
        settings.showHints = isEnabled
        persistSettings()
    }

    func updateSoundFeedback(_ isEnabled: Bool) {
        settings.enableSoundFeedback = isEnabled
        persistSettings()
    }

    func updatePreferredDifficulty(_ difficulty: SchulteDifficulty) {
        settings.preferredDifficulty = difficulty
        persistSettings()
    }

    func elapsedTimeString(at date: Date) -> String {
        guard let activeEngine else { return "--" }
        return DurationFormatter.training.string(from: activeEngine.elapsedDuration(at: date)) ?? "00:00"
    }

    func formattedDuration(_ duration: TimeInterval) -> String {
        DurationFormatter.training.string(from: duration) ?? "00:00"
    }

    func formattedDate(_ date: Date) -> String {
        DateFormatter.trainingTimestamp.string(from: date)
    }

    private func persistResults() {
        do {
            try store.saveResults(history)
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = "记录保存失败：\(error.localizedDescription)"
        }
    }

    private func persistSettings() {
        do {
            try store.saveSettings(settings)
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = "设置保存失败：\(error.localizedDescription)"
        }
    }
}
