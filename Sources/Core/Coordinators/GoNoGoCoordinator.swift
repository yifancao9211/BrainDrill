import Foundation
import Observation

@Observable
final class GoNoGoCoordinator {
    var engine: GoNoGoEngine?
    var statusMessage: String = "Go/No-Go 训练：绿色圆形快速点击，红色方形忍住不动。"
    var lastResult: SessionResult?

    var isActive: Bool { engine != nil && !(engine?.isComplete ?? true) }

    func startSession(settings: TrainingSettings) {
        let config = GoNoGoSessionConfig()
        engine = GoNoGoEngine(config: config)
        lastResult = nil
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

    func cancelSession() {
        engine = nil
        statusMessage = "已取消 Go/No-Go 训练。"
    }

    private func buildResult() -> SessionResult? {
        guard let engine else { return nil }
        let metrics = engine.computeMetrics()
        let now = Date()
        let result = SessionResult(
            module: .goNoGo,
            startedAt: engine.startedAt,
            endedAt: now,
            duration: now.timeIntervalSince(engine.startedAt),
            metrics: .goNoGo(metrics)
        )
        lastResult = result
        statusMessage = "Go/No-Go 完成 — d' \(String(format: "%.2f", metrics.dPrime))"
        self.engine = nil
        return result
    }
}
