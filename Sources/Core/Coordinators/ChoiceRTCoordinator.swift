import Foundation
import Observation

@Observable
final class ChoiceRTCoordinator {
    var engine: ChoiceRTEngine?
    var statusMessage: String = "选择反应时训练：看到颜色后快速按对应键。"
    var lastResult: SessionResult?

    var isActive: Bool { engine != nil && !(engine?.isComplete ?? true) }

    func startSession(settings: TrainingSettings) {
        let config = ChoiceRTSessionConfig(
            choiceCount: settings.choiceRTChoiceCount,
            trialsPerBlock: settings.choiceRTTrialsPerBlock
        )
        engine = ChoiceRTEngine(config: config)
        lastResult = nil
        statusMessage = "注视中央，看到颜色后快速按对应键"
    }

    func handleResponse(_ responseIndex: Int, at date: Date = Date()) -> SessionResult? {
        guard let engine else { return nil }
        _ = engine.recordResponse(responseIndex, at: date)
        engine.advanceToNext()
        if engine.isComplete {
            return buildResult()
        }
        return nil
    }

    func handleTimeout() {
        guard let engine else { return }
        engine.recordTimeout()
        engine.advanceToNext()
    }

    func cancelSession() {
        engine = nil
        statusMessage = "已取消选择反应时训练。"
    }

    private func buildResult() -> SessionResult? {
        guard let engine else { return nil }
        let metrics = engine.computeMetrics()
        let now = Date()
        let result = SessionResult(
            module: .choiceRT,
            startedAt: engine.startedAt,
            endedAt: now,
            duration: now.timeIntervalSince(engine.startedAt),
            metrics: .choiceRT(metrics)
        )
        lastResult = result
        statusMessage = "选择反应时完成 — 中位 RT \(String(format: "%.0f", metrics.medianRT * 1000))ms"
        self.engine = nil
        return result
    }
}
