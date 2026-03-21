import Foundation
import Observation

@Observable
final class DigitSpanCoordinator {
    var engine: DigitSpanEngine?
    var statusMessage: String = "数字广度训练：记住数字序列并按顺序复述。"
    var lastResult: SessionResult?

    var isActive: Bool { engine != nil && !(engine?.isComplete ?? true) }

    private var sessionConditions = SessionConditions()

    func startSession(settings: TrainingSettings, mode: DigitSpanMode = .forward) {
        let config = DigitSpanSessionConfig(
            startingLength: settings.digitSpanStartingLength,
            presentationMs: settings.digitSpanPresentationMs,
            mode: mode
        )
        engine = DigitSpanEngine(config: config)
        lastResult = nil
        sessionConditions = SessionConditions(
            hintsEnabled: false,
            feedbackEnabled: true,
            adaptiveEnabled: true,
            customParameters: [
                "mode": config.mode.rawValue,
                "startingLength": "\(config.startingLength)",
                "maxLength": "\(config.maxLength)",
                "presentationMs": "\(config.presentationMs)"
            ]
        )
        statusMessage = mode == .forward ? "记住数字顺序并正序复述" : "记住数字顺序并倒序复述"
        engine?.beginNextTrial()
    }

    func submitResponse(_ userInput: [Int]) -> SessionResult? {
        guard let engine else { return nil }
        _ = engine.submitResponse(userInput)
        return nil
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
        statusMessage = "已取消数字广度训练。"
    }

    private func buildResult() -> SessionResult? {
        guard let engine else { return nil }
        let metrics = engine.computeMetrics()
        let now = Date()
        let span = max(metrics.maxSpanForward, metrics.maxSpanBackward)
        let result = SessionResult(
            module: .digitSpan,
            startedAt: engine.startedAt,
            endedAt: now,
            duration: now.timeIntervalSince(engine.startedAt),
            metrics: .digitSpan(metrics),
            conditions: sessionConditions
        )
        lastResult = result
        statusMessage = "数字广度完成 — 最大广度 \(span)"
        self.engine = nil
        return result
    }
}
