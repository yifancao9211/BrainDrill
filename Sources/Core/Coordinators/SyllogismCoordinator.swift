import Foundation
import Observation

@Observable
final class SyllogismCoordinator {
    var engine: SyllogismEngine?
    var statusMessage: String = "逻辑快判：限时判断推理是否有效。"
    var lastResult: SessionResult?

    var isActive: Bool { engine != nil && !(engine?.isComplete ?? true) }

    private(set) var sessionConditions = SessionConditions()
    private(set) var sessionsCompleted: Int = 0

    func startSession(adaptiveState: ModuleAdaptiveState) {
        let difficulty = adaptiveState.recommendedStartLevel
        engine = SyllogismEngine(difficulty: difficulty)
        lastResult = nil
        sessionConditions = SessionConditions(
            feedbackEnabled: true,
            adaptiveEnabled: true,
            customParameters: [
                "startingLevel": "\(difficulty)"
            ]
        )
        statusMessage = "判断推理是否有效，注意时间限制"
    }

    func handleResponse(userSaysValid: Bool, at date: Date = Date()) {
        engine?.recordResponse(userSaysValid: userSaysValid, at: date)
    }

    func handleTimeout() {
        engine?.recordTimeout()
    }

    func advanceToNext() {
        engine?.advanceToNext()
    }

    func finalizeIfComplete() -> SessionResult? {
        guard let engine, engine.isComplete else { return nil }
        return buildResult()
    }

    func cancelSession() {
        engine = nil
        statusMessage = "已取消逻辑快判训练。"
    }

    private func buildResult() -> SessionResult? {
        guard let engine else { return nil }
        let metrics = engine.computeMetrics()
        let now = Date()

        var conditions = sessionConditions
        conditions.customParameters["finalLevel"] = "\(engine.difficulty)"
        conditions.customParameters["recommendedStartLevel"] = "\(engine.difficulty)"

        let result = SessionResult(
            module: .syllogism,
            startedAt: engine.startedAt,
            endedAt: now,
            duration: now.timeIntervalSince(engine.startedAt),
            metrics: .syllogism(metrics),
            conditions: conditions
        )
        lastResult = result
        sessionsCompleted += 1
        statusMessage = "逻辑快判完成 — 准确率 \(String(format: "%.0f", metrics.accuracy * 100))%  d'=\(String(format: "%.1f", metrics.dPrime))"
        self.engine = nil
        return result
    }
}
