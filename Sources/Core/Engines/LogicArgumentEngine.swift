import Foundation
import Observation

@Observable
final class LogicArgumentEngine {
    let passage: LogicArgumentPassage
    let startedAt: Date

    private(set) var phase: Phase = .reading
    private(set) var componentSelections: [String: ArgumentComponentRole] = [:]
    private(set) var fallacySelections: [String: LogicalFallacy] = [:]
    private(set) var assumptionSelection: Int?
    private(set) var modifierSelections: [String: ArgumentModifierType] = [:]

    enum Phase: Equatable {
        case reading
        case structureAnnotation
        case fallacyDetection
        case argumentEvaluation
        case completed
    }

    var isComplete: Bool { phase == .completed }

    var currentPhaseTitle: String {
        switch phase {
        case .reading:              "阅读论述"
        case .structureAnnotation:  "结构标注"
        case .fallacyDetection:     "谬误侦测"
        case .argumentEvaluation:   "论证评估"
        case .completed:            "训练完成"
        }
    }

    var currentPhaseSubtitle: String {
        switch phase {
        case .reading:
            "仔细阅读下方论述，完成后开始分析。"
        case .structureAnnotation:
            "为每个句子标注它在论证中的角色：前提、结论、背景还是反驳？"
        case .fallacyDetection:
            "判断论证中是否存在逻辑谬误，如果有，是哪一种？"
        case .argumentEvaluation:
            "找出论证的隐含假设，并判断哪些信息能加强或削弱该论证。"
        case .completed:
            "所有阶段完成，查看结果。"
        }
    }

    init(passage: LogicArgumentPassage, startedAt: Date = Date()) {
        self.passage = passage
        self.startedAt = startedAt
    }

    // MARK: - Phase transitions

    func beginAnnotation() {
        phase = .structureAnnotation
    }

    func submitStructureAnnotation() {
        phase = .fallacyDetection
    }

    func submitFallacyDetection() {
        if passage.requiresEvaluation && !passage.evaluationItems.isEmpty {
            phase = .argumentEvaluation
        } else {
            phase = .completed
        }
    }

    func submitArgumentEvaluation() {
        phase = .completed
    }

    // MARK: - User actions

    func selectComponentRole(_ componentID: String, role: ArgumentComponentRole) {
        componentSelections[componentID] = role
    }

    func selectFallacy(_ itemID: String, fallacy: LogicalFallacy) {
        fallacySelections[itemID] = fallacy
    }

    func selectAssumption(_ index: Int) {
        assumptionSelection = index
    }

    func selectModifierType(_ modifierID: String, type: ArgumentModifierType) {
        modifierSelections[modifierID] = type
    }

    // MARK: - Readiness checks

    var canSubmitStructure: Bool {
        passage.argumentComponents.allSatisfy { componentSelections[$0.id] != nil }
    }

    var canSubmitFallacy: Bool {
        passage.fallacyItems.allSatisfy { fallacySelections[$0.id] != nil }
    }

    var canSubmitEvaluation: Bool {
        guard let firstEval = passage.evaluationItems.first else { return true }
        let hasAssumption = assumptionSelection != nil
        let hasModifiers = firstEval.modifierStatements.allSatisfy { modifierSelections[$0.id] != nil }
        return hasAssumption && hasModifiers
    }

    // MARK: - Metrics

    func computeMetrics() -> LogicArgumentMetrics {
        let now = Date()

        // Phase 1: Structure
        let componentTotal = passage.argumentComponents.count
        let componentCorrect = passage.argumentComponents.filter { componentSelections[$0.id] == $0.role }.count
        let componentAccuracy = componentTotal > 0 ? Double(componentCorrect) / Double(componentTotal) : 0

        // Phase 2: Fallacy
        let fallacyTotal = passage.fallacyItems.count
        let fallacyCorrect = passage.fallacyItems.filter { fallacySelections[$0.id] == $0.correctFallacy }.count
        let fallacyAccuracy = fallacyTotal > 0 ? Double(fallacyCorrect) / Double(fallacyTotal) : 0

        // Phase 3: Evaluation
        var assumptionCorrect = false
        var modifierTotal = 0
        var modifierCorrect = 0

        if let eval = passage.evaluationItems.first {
            assumptionCorrect = assumptionSelection == eval.correctAssumptionIndex
            modifierTotal = eval.modifierStatements.count
            modifierCorrect = eval.modifierStatements.filter { modifierSelections[$0.id] == $0.type }.count
        }

        let modifierAccuracy = modifierTotal > 0 ? Double(modifierCorrect) / Double(modifierTotal) : 0

        return LogicArgumentMetrics(
            passageID: passage.id,
            difficulty: passage.difficulty,
            componentTotal: componentTotal,
            componentCorrect: componentCorrect,
            componentAccuracy: componentAccuracy,
            fallacyTotal: fallacyTotal,
            fallacyCorrect: fallacyCorrect,
            fallacyAccuracy: fallacyAccuracy,
            assumptionCorrect: assumptionCorrect,
            modifierTotal: modifierTotal,
            modifierCorrect: modifierCorrect,
            modifierAccuracy: modifierAccuracy,
            responseDuration: now.timeIntervalSince(startedAt)
        )
    }
}
