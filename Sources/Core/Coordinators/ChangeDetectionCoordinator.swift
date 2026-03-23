import Foundation
import Observation

@Observable
final class ChangeDetectionCoordinator {
    var engine: ChangeDetectionEngine?
    var statusMessage: String = "变更检测训练：记住颜色方块，判断是否变化。"
    var lastResult: SessionResult?

    var isActive: Bool { engine != nil && !(engine?.isComplete ?? true) }

    private(set) var sessionConditions = SessionConditions()

    func startSession(settings: TrainingSettings, adaptiveState: ModuleAdaptiveState = .default(for: .changeDetection)) {
        let initialSetSize = settings.adaptiveDifficultyEnabled
            ? min(max(adaptiveState.recommendedStartLevel + 1, 2), 6)
            : settings.changeDetectionInitialSetSize
        let config = ChangeDetectionSessionConfig(
            initialSetSize: initialSetSize,
            encodingMs: settings.changeDetectionEncodingMs,
            retentionMs: settings.changeDetectionRetentionMs,
            trialsPerBlock: 12
        )
        engine = ChangeDetectionEngine(config: config)
        lastResult = nil
        sessionConditions = SessionConditions(
            hintsEnabled: false,
            feedbackEnabled: true,
            adaptiveEnabled: true,
            customParameters: [
                "initialSetSize": "\(config.initialSetSize)",
                "maxSetSize": "\(config.maxSetSize)",
                "encodingMs": "\(config.encodingMs)",
                "retentionMs": "\(config.retentionMs)",
                "trialsPerBlock": "\(config.trialsPerBlock)",
                "blockCount": "\(config.blockCount)",
                "changeRatio": "\(config.changeRatio)"
            ]
        )
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
            metrics: .changeDetection(metrics),
            conditions: sessionConditions
        )
        lastResult = result
        statusMessage = "变更检测完成 — d' \(String(format: "%.2f", metrics.dPrime))"
        self.engine = nil
        return result
    }
}
