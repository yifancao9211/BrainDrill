import Foundation
import Observation

@Observable
final class CorsiBlockCoordinator {
    var engine: CorsiBlockEngine?
    var statusMessage: String = "空间广度训练：记住方块亮起的顺序并复现。"
    var lastResult: SessionResult?

    var isActive: Bool { engine != nil && !(engine?.isComplete ?? true) }

    private var sessionConditions = SessionConditions()

    func startSession(mode: CorsiBlockMode = .forward) {
        let config = CorsiBlockSessionConfig(mode: mode)
        engine = CorsiBlockEngine(config: config)
        lastResult = nil
        sessionConditions = SessionConditions(
            hintsEnabled: false,
            feedbackEnabled: true,
            adaptiveEnabled: true,
            customParameters: [
                "mode": config.mode.rawValue,
                "startingLength": "\(config.startingLength)",
                "maxLength": "\(config.maxLength)",
                "presentationMs": "\(config.presentationMs)",
                "gridSize": "\(config.gridSize)"
            ]
        )
        statusMessage = mode == .forward ? "记住方块亮起顺序并正序点击" : "记住方块亮起顺序并倒序点击"
        engine?.beginNextTrial()
    }

    func submitResponse(_ userInput: [Int]) {
        guard let engine else { return }
        _ = engine.submitResponse(userInput)
    }

    func advanceAfterFeedback() -> SessionResult? {
        guard let engine else { return nil }
        engine.advanceAfterFeedback()
        if engine.isComplete {
            return buildResult()
        }
        return nil
    }

    func cancelSession() {
        engine = nil
        statusMessage = "已取消空间广度训练。"
    }

    private func buildResult() -> SessionResult? {
        guard let engine else { return nil }
        let metrics = engine.computeMetrics()
        let now = Date()
        let result = SessionResult(
            module: .corsiBlock,
            startedAt: engine.startedAt,
            endedAt: now,
            duration: now.timeIntervalSince(engine.startedAt),
            metrics: .corsiBlock(metrics),
            conditions: sessionConditions
        )
        lastResult = result
        statusMessage = "空间广度完成 — 最大广度 \(metrics.maxSpan)"
        self.engine = nil
        return result
    }
}
