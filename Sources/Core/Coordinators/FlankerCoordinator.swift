import Foundation
import Observation

@Observable
final class FlankerCoordinator {
    var engine: FlankerEngine?
    var statusMessage: String = "Flanker 训练：快速判断中间箭头的方向。"
    var lastResult: SessionResult?

    var isActive: Bool { engine != nil && !(engine?.isComplete ?? true) }

    func startSession(settings: TrainingSettings) {
        let config = FlankerSessionConfig(
            stimulusDurationMs: settings.flankerStimulusDurationMs
        )
        engine = FlankerEngine(config: config)
        lastResult = nil
        statusMessage = "注视中央 + 号，快速判断中间箭头方向"
    }

    func handleResponse(_ direction: FlankerDirection, at date: Date = Date()) -> SessionResult? {
        guard let engine else { return nil }
        _ = engine.recordResponse(direction, at: date)

        engine.advanceToNext()

        if engine.isComplete {
            return buildResult()
        }
        return nil
    }

    func cancelSession() {
        engine = nil
        statusMessage = "已取消 Flanker 训练。"
    }

    private func buildResult() -> SessionResult? {
        guard let engine else { return nil }
        let metrics = engine.computeMetrics()
        let now = Date()
        let result = SessionResult(
            module: .flanker,
            startedAt: engine.startedAt,
            endedAt: now,
            duration: now.timeIntervalSince(engine.startedAt),
            metrics: .flanker(metrics)
        )
        lastResult = result
        statusMessage = "Flanker 完成 — 冲突代价 \(String(format: "%.0f", metrics.conflictCost * 1000))ms"
        self.engine = nil
        return result
    }
}
