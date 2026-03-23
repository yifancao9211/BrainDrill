import Foundation
import Observation

@Observable
final class GoNoGoCoordinator {
    var engine: GoNoGoEngine?
    var statusMessage: String = "Go/No-Go 训练：绿色圆形快速点击，红色方形忍住不动。"
    var lastResult: SessionResult?

    var isActive: Bool { engine != nil && !(engine?.isComplete ?? true) }

    private(set) var sessionConditions = SessionConditions()

    func startSession(settings: TrainingSettings, adaptiveState: ModuleAdaptiveState = .default(for: .goNoGo)) {
        let startLevel = adaptiveState.recommendedStartLevel
        let config = settings.adaptiveDifficultyEnabled
            ? GoNoGoSessionConfig(blockCount: 2, startingLevel: startLevel)
            : GoNoGoSessionConfig()
        engine = GoNoGoEngine(config: config)
        lastResult = nil
        sessionConditions = SessionConditions(
            feedbackEnabled: true,
            adaptiveEnabled: settings.adaptiveDifficultyEnabled,
            customParameters: ["startingLevel": "\(engine?.currentLevel ?? startLevel)"]
        )
        statusMessage = "绿色 → 点击，红色 → 不动"
    }

    func handleTap(at date: Date = Date()) -> SessionResult? {
        guard let engine else { return nil }
        _ = engine.recordTap(at: date)
        engine.advanceToNext()
        if engine.isComplete {
            return buildResult()
        }
        return nil
    }

    func finalizeIfComplete() -> SessionResult? {
        guard let engine, engine.isComplete else { return nil }
        return buildResult()
    }

    func cancelSession() {
        engine = nil
        statusMessage = "已取消 Go/No-Go 训练。"
    }

    private func buildResult() -> SessionResult? {
        guard let engine else { return nil }
        let metrics = engine.computeMetrics()
        let now = Date()
        var conditions = sessionConditions
        conditions.customParameters["finalLevel"] = "\(engine.currentLevel)"
        conditions.customParameters["recommendedStartLevel"] = "\(engine.currentLevel)"
        conditions.customParameters["levelTrace"] = engine.blockLevelHistory.map(String.init).joined(separator: ",")
        conditions.customParameters["blockOutcomes"] = engine.blockOutcomes.map(\.rawValue).joined(separator: ",")
        let result = SessionResult(
            module: .goNoGo,
            startedAt: engine.startedAt,
            endedAt: now,
            duration: now.timeIntervalSince(engine.startedAt),
            metrics: .goNoGo(metrics),
            conditions: conditions
        )
        lastResult = result
        statusMessage = "Go/No-Go 完成 — d' \(String(format: "%.2f", metrics.dPrime))"
        self.engine = nil
        return result
    }
}
