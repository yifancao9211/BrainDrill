import Foundation
import Observation

@Observable
final class VisualSearchCoordinator {
    var engine: VisualSearchEngine?
    var statusMessage: String = "视觉搜索训练：在干扰物中找到目标。"
    var lastResult: SessionResult?

    var isActive: Bool { engine != nil && !(engine?.isComplete ?? true) }

    private(set) var sessionConditions = SessionConditions()

    func startSession(settings: TrainingSettings, adaptiveState: ModuleAdaptiveState = .default(for: .visualSearch)) {
        let startLevel = adaptiveState.recommendedStartLevel
        let config = settings.adaptiveDifficultyEnabled
            ? VisualSearchSessionConfig(blockCount: 2, startingLevel: startLevel)
            : VisualSearchSessionConfig(setSizes: settings.visualSearchSetSizes, trialsPerSize: settings.visualSearchTrialsPerSize)
        engine = VisualSearchEngine(config: config)
        lastResult = nil
        sessionConditions = SessionConditions(
            hintsEnabled: false,
            feedbackEnabled: true,
            adaptiveEnabled: settings.adaptiveDifficultyEnabled,
            customParameters: [
                "startingLevel": "\(engine?.currentLevel ?? startLevel)",
                "setSizes": (engine?.currentSpec.setSizes ?? settings.visualSearchSetSizes).map(String.init).joined(separator: ","),
                "trialsPerBlock": "\(engine?.currentSpec.trialsPerBlock ?? settings.visualSearchSetSizes.count * settings.visualSearchTrialsPerSize)",
                "targetPresentRatio": "\(config.targetPresentRatio)",
                "fixationMs": "\(engine?.currentSpec.fixationMs ?? 500)",
                "feedbackMs": "\(engine?.currentSpec.feedbackMs ?? 300)"
            ]
        )
        if engine != nil {
            statusMessage = "迅速判断视场中是否包含要求的目标"
        }
    }

    func handleResponse(userSaidPresent: Bool, at date: Date = Date()) -> SessionResult? {
        guard let engine else { return nil }
        _ = engine.recordResponse(userSaidPresent: userSaidPresent, at: date)
        // Don't advanceToNext() here — let the feedback phase display first.
        // The view's schedulePhase will call advanceToNext() after feedbackMs.
        return nil
    }

    func cancelSession() {
        engine = nil
        statusMessage = "已取消视觉搜索训练。"
    }

    private func buildResult() -> SessionResult? {
        guard let engine else { return nil }
        let metrics = engine.computeMetrics()
        let now = Date()
        var conditions = sessionConditions
        conditions.customParameters["finalLevel"] = "\(engine.currentLevel)"
        conditions.customParameters["recommendedStartLevel"] = "\(engine.currentLevel)"
        conditions.customParameters["levelTrace"] = engine.blockLevelHistory.map(String.init).joined(separator: ",")
        conditions.customParameters["blockOutcomes"] = engine.blockOutcomes.map(\.rawValue).joined(separator: ",")
        let result = SessionResult(
            module: .visualSearch,
            startedAt: engine.startedAt,
            endedAt: now,
            duration: now.timeIntervalSince(engine.startedAt),
            metrics: .visualSearch(metrics),
            conditions: conditions
        )
        lastResult = result
        statusMessage = "视觉搜索完成 — 搜索斜率 \(String(format: "%.0f", metrics.searchSlope * 1000))ms/项"
        self.engine = nil
        return result
    }

    private func colorName(_ color: SearchColor) -> String {
        switch color {
        case .red:   "红色"
        case .blue:  "蓝色"
        case .green: "绿色"
        }
    }

    private func shapeName(_ shape: SearchShape) -> String {
        switch shape {
        case .circle:   "圆形"
        case .square:   "方块"
        case .triangle: "三角"
        }
    }
}
