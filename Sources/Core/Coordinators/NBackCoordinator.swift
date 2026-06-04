import Foundation
import Observation

@Observable
final class NBackCoordinator: TrainingModuleCoordinator {
    var engine: NBackEngine?
    var statusMessage: String = "N-Back 训练：判断当前数字是否与 N 步前相同。"
    var lastResult: SessionResult?

    var isActive: Bool { engine != nil && !(engine?.isComplete ?? true) }

    private(set) var sessionConditions = SessionConditions()

    func startSession(settings: TrainingSettings) {
        let config = NBackSessionConfig(
            startingN: settings.nBackStartingN,
            practiceTrials: 4,
            stimulusDurationMs: settings.nBackStimulusDurationMs,
            isiMs: settings.nBackISIMs
        )
        engine = NBackEngine(config: config)
        lastResult = nil
        sessionConditions = SessionConditions(
            hintsEnabled: false,
            feedbackEnabled: false,
            adaptiveEnabled: false,
            customParameters: [
                "startingN": "\(config.startingN)",
                "maxN": "\(config.maxN)",
                "trialsPerBlock": "\(config.trialsPerBlock)",
                "blockCount": "\(config.blockCount)",
                "targetRatio": "\(config.targetRatio)",
                "referenceStimulusDurationMs": "\(config.stimulusDurationMs)",
                "referenceISIMs": "\(config.isiMs)",
                "pacing": "auto"
            ]
        )
        statusMessage = "\(config.startingN)-Back — 数字自动播放，与 \(config.startingN) 步前相同时按「匹配」"
    }

    func startSession(settings: TrainingSettings, adaptiveState: ModuleAdaptiveState) {
        let startLevel = settings.adaptiveDifficultyEnabled ? adaptiveState.recommendedStartLevel : settings.nBackStartingN
        let timing = AdaptiveScoring.nBackTiming(
            level: startLevel,
            internalSkillScore: adaptiveState.internalSkillScore,
            slowDownAfterPoorBlock: false
        )
        let config = NBackSessionConfig(
            startingN: startLevel,
            practiceTrials: 4,
            stimulusDurationMs: timing.stimulusMs,
            isiMs: timing.isiMs,
            internalSkillScore: adaptiveState.internalSkillScore
        )
        engine = NBackEngine(config: config)
        lastResult = nil
        sessionConditions = SessionConditions(
            hintsEnabled: false,
            feedbackEnabled: false,
            adaptiveEnabled: true,
            customParameters: [
                "startingN": "\(config.startingN)",
                "maxN": "\(config.maxN)",
                "trialsPerBlock": "\(config.trialsPerBlock)",
                "blockCount": "\(config.blockCount)",
                "targetRatio": "\(config.targetRatio)",
                "referenceStimulusDurationMs": "\(config.stimulusDurationMs)",
                "referenceISIMs": "\(config.isiMs)",
                "pacing": "auto"
            ]
        )
        statusMessage = "\(startLevel)-Back — 数字自动播放，与 \(startLevel) 步前相同时按「匹配」"
    }

    /// Register a single "match" response for the current trial.
    func handleMatch(at date: Date = Date()) {
        engine?.recordMatch(at: date)
    }

    /// Build the session result once the auto-paced stream has finished.
    func finalizeIfComplete() -> SessionResult? {
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
        var conditions = sessionConditions
        conditions.customParameters["finalLevel"] = "\(engine.currentN)"
        conditions.customParameters["recommendedStartLevel"] = "\(engine.currentN)"
        conditions.customParameters["averageDecisionInterval"] = String(format: "%.4f", metrics.averageDecisionInterval)
        let result = SessionResult(
            module: .nBack,
            startedAt: engine.startedAt,
            endedAt: now,
            duration: now.timeIntervalSince(engine.startedAt),
            metrics: .nBack(metrics),
            conditions: conditions
        )
        lastResult = result
        statusMessage = "N-Back 完成 — \(metrics.nLevel)-Back d' \(String(format: "%.2f", metrics.dPrime))，均间隔 \(String(format: "%.1f", metrics.averageDecisionInterval))s"
        self.engine = nil
        return result
    }
}
