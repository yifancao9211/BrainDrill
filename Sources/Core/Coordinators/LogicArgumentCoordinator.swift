import Foundation
import Observation

@Observable
final class LogicArgumentCoordinator: TrainingModuleCoordinator {
    var engine: LogicArgumentEngine?
    var statusMessage: String = "论证分析：拆结构、找谬误、评论证。"
    var lastResult: SessionResult?

    var isActive: Bool { engine != nil && !(engine?.isComplete ?? true) }

    private(set) var sessionConditions = SessionConditions()

    /// Rolling list of recently-served passage IDs (persisted, oldest→newest), so
    /// every passage is shown before any repeats. Capped to keep it bounded.
    private static let recentPassageCap = 60

    var recentPassageIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: "logicArgument_recent_passages") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "logicArgument_recent_passages") }
    }

    func startSession(difficulty: Int) {
        let passage = LogicArgumentPassageLibrary.nextPassage(
            difficulty: difficulty,
            recentIDs: recentPassageIDs
        )

        var recent = recentPassageIDs
        recent.append(passage.id)
        if recent.count > Self.recentPassageCap {
            recent.removeFirst(recent.count - Self.recentPassageCap)
        }
        recentPassageIDs = recent

        engine = LogicArgumentEngine(passage: passage)
        lastResult = nil
        sessionConditions = SessionConditions(
            feedbackEnabled: true,
            adaptiveEnabled: true,
            customParameters: [
                "startingLevel": "\(difficulty)",
                "passageID": passage.id
            ]
        )
        statusMessage = "阅读论述并准备分析"
    }

    func startSession(adaptiveState: ModuleAdaptiveState) {
        startSession(difficulty: adaptiveState.recommendedStartLevel)
    }

    func finalizeIfComplete() -> SessionResult? {
        guard let engine, engine.isComplete else { return nil }
        return buildResult()
    }

    func cancelSession() {
        engine = nil
        statusMessage = "已取消论证分析训练。"
    }

    private func buildResult() -> SessionResult? {
        guard let engine else { return nil }
        let metrics = engine.computeMetrics()
        let now = Date()

        var conditions = sessionConditions
        conditions.customParameters["finalLevel"] = "\(engine.passage.difficulty)"
        conditions.customParameters["recommendedStartLevel"] = "\(engine.passage.difficulty)"

        let result = SessionResult(
            module: .logicArgument,
            startedAt: engine.startedAt,
            endedAt: now,
            duration: now.timeIntervalSince(engine.startedAt),
            metrics: .logicArgument(metrics),
            conditions: conditions
        )
        lastResult = result
        statusMessage = "论证分析完成 — 综合得分 \(String(format: "%.0f", metrics.compositeScore * 100))%"
        self.engine = nil
        return result
    }
}
