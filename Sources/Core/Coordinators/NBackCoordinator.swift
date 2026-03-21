import Foundation
import Observation

@Observable
final class NBackCoordinator {
    var engine: NBackEngine?
    var statusMessage: String = "N-Back 训练：判断当前数字是否与 N 步前相同。"
    var lastResult: SessionResult?

    var isActive: Bool { engine != nil && !(engine?.isComplete ?? true) }

    private var sessionConditions = SessionConditions()

    func startSession(settings: TrainingSettings) {
        let config = NBackSessionConfig(startingN: settings.nBackStartingN)
        engine = NBackEngine(config: config)
        lastResult = nil
        sessionConditions = SessionConditions(
            hintsEnabled: false,
            feedbackEnabled: true,
            adaptiveEnabled: true,
            customParameters: [
                "startingN": "\(config.startingN)",
                "maxN": "\(config.maxN)",
                "trialsPerBlock": "\(config.trialsPerBlock)",
                "blockCount": "\(config.blockCount)",
                "targetRatio": "\(config.targetRatio)"
            ]
        )
        statusMessage = "\(settings.nBackStartingN)-Back — 当前数字与 \(settings.nBackStartingN) 步前相同时点击「匹配」"
    }

    func handleMatch(at date: Date = Date()) -> SessionResult? {
        guard let engine else { return nil }
        _ = engine.recordMatch(at: date)

        engine.advanceToNext()

        if engine.isComplete {
            return buildResult()
        }
        return nil
    }

    func buildResultIfComplete() -> SessionResult? {
        guard let engine, engine.isComplete else { return nil }
        return buildResult()
    }

    func cancelSession() {
        engine = nil
        statusMessage = "已取消 N-Back 训练。"
    }

    private func buildResult() -> SessionResult? {
        guard let engine else { return nil }
        let metrics = engine.computeMetrics()
        let now = Date()
        let result = SessionResult(
            module: .nBack,
            startedAt: engine.startedAt,
            endedAt: now,
            duration: now.timeIntervalSince(engine.startedAt),
            metrics: .nBack(metrics),
            conditions: sessionConditions
        )
        lastResult = result
        statusMessage = "N-Back 完成 — \(metrics.nLevel)-Back d' \(String(format: "%.2f", metrics.dPrime))"
        self.engine = nil
        return result
    }
}
