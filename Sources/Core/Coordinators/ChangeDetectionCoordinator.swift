import Foundation
import Observation

@Observable
final class ChangeDetectionCoordinator {
    var engine: ChangeDetectionEngine?
    var statusMessage: String = "变更检测训练：记住颜色方块，判断是否变化。"
    var lastResult: SessionResult?

    var isActive: Bool { engine != nil && !(engine?.isComplete ?? true) }

    func startSession(settings: TrainingSettings) {
        let config = ChangeDetectionSessionConfig(
            initialSetSize: settings.changeDetectionInitialSetSize,
            encodingMs: settings.changeDetectionEncodingMs,
            retentionMs: settings.changeDetectionRetentionMs
        )
        engine = ChangeDetectionEngine(config: config)
        lastResult = nil
        statusMessage = "记住颜色方块的位置和颜色"
    }

    func handleResponse(userSaidChanged: Bool, at date: Date = Date()) -> SessionResult? {
        guard let engine else { return nil }
        _ = engine.recordResponse(userSaidChanged: userSaidChanged, at: date)
        engine.advanceToNext()
        if engine.isComplete {
            return buildResult()
        }
        return nil
    }

    func cancelSession() {
        engine = nil
        statusMessage = "已取消变更检测训练。"
    }

    private func buildResult() -> SessionResult? {
        guard let engine else { return nil }
        let metrics = engine.computeMetrics()
        let now = Date()
        let result = SessionResult(
            module: .changeDetection,
            startedAt: engine.startedAt,
            endedAt: now,
            duration: now.timeIntervalSince(engine.startedAt),
            metrics: .changeDetection(metrics)
        )
        lastResult = result
        statusMessage = "变更检测完成 — d' \(String(format: "%.2f", metrics.dPrime))"
        self.engine = nil
        return result
    }
}
