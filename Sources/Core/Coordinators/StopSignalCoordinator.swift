import Foundation
import Observation

@Observable
final class StopSignalCoordinator {
    var engine: StopSignalEngine?
    var statusMessage: String = "Stop-Signal 训练：看到箭头快速按键，出现红点立刻停止。"
    var lastResult: SessionResult?

    var isActive: Bool { engine != nil && !(engine?.isComplete ?? true) }

    private(set) var sessionConditions = SessionConditions()

    func startSession(adaptiveState: ModuleAdaptiveState = .default(for: .stopSignal)) {
        let config = StopSignalSessionConfig(
            trialsPerBlock: 24,
            blockCount: 2,
            fixationMs: 400,
            responseWindowMs: 850,
            itiRangeMs: 400...800
        )
        engine = StopSignalEngine(config: config)
        lastResult = nil
        sessionConditions = SessionConditions(
            hintsEnabled: false,
            feedbackEnabled: true,
            adaptiveEnabled: true,
            customParameters: [
                "trialsPerBlock": "\(config.trialsPerBlock)",
                "blockCount": "\(config.blockCount)",
                "stopRatio": "\(config.stopRatio)",
                "initialSSD": "\(config.initialSSD)",
                "ssdStepMs": "\(config.ssdStepMs)",
                "responseWindowMs": "\(config.responseWindowMs)",
                "startingLevel": "\(adaptiveState.recommendedStartLevel)"
            ]
        )
        statusMessage = "看到箭头按方向键，听到停止信号忍住不按"
    }

    func handleResponse(_ direction: StopSignalDirection, at date: Date = Date()) -> SessionResult? {
        guard let engine else { return nil }
        _ = engine.recordResponse(direction, at: date)
        engine.advanceToNext()
        if engine.isComplete {
            return buildResult()
        }
        return nil
    }

    func handleStopTimeout() {
        guard let engine else { return }
        engine.recordStopTimeout()
        engine.advanceToNext()
    }

    func handleGoTimeout() {
        guard let engine else { return }
        engine.recordGoTimeout()
        engine.advanceToNext()
    }

    func cancelSession() {
        engine = nil
        statusMessage = "已取消 Stop-Signal 训练。"
    }

    private func buildResult() -> SessionResult? {
        guard let engine else { return nil }
        let metrics = engine.computeMetrics()
        let now = Date()
        let result = SessionResult(
            module: .stopSignal,
            startedAt: engine.startedAt,
            endedAt: now,
            duration: now.timeIntervalSince(engine.startedAt),
            metrics: .stopSignal(metrics),
            conditions: sessionConditions
        )
        lastResult = result
        statusMessage = "Stop-Signal 完成 — SSRT \(String(format: "%.0f", metrics.ssrt * 1000))ms"
        self.engine = nil
        return result
    }
}
