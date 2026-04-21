import Foundation

// MARK: - Argument Structure

enum ArgumentComponentRole: String, Codable, CaseIterable, Identifiable {
    case premise
    case conclusion
    case subConclusion
    case background
    case counterpoint

    var id: String { rawValue }

    var label: String {
        switch self {
        case .premise:       "前提"
        case .conclusion:    "结论"
        case .subConclusion: "中间结论"
        case .background:    "背景"
        case .counterpoint:  "反驳/让步"
        }
    }
}

struct ArgumentComponent: Codable, Identifiable, Equatable {
    let id: String
    let text: String
    let role: ArgumentComponentRole
    let supportsConclusionID: String?
}

// MARK: - Logical Fallacies

enum LogicalFallacy: String, Codable, CaseIterable, Identifiable {
    case adHominem
    case strawMan
    case falseDisjunction
    case slipperySlope
    case appealToAuthority
    case appealToEmotion
    case hastyGeneralization
    case circularReasoning
    case redHerring
    case falseCause
    case equivocation
    case appealToTradition
    case bandwagon
    case noFallacy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .adHominem:           "人身攻击"
        case .strawMan:            "稻草人谬误"
        case .falseDisjunction:    "假二选一"
        case .slipperySlope:       "滑坡谬误"
        case .appealToAuthority:   "诉诸权威"
        case .appealToEmotion:     "诉诸情感"
        case .hastyGeneralization: "以偏概全"
        case .circularReasoning:   "循环论证"
        case .redHerring:          "转移话题"
        case .falseCause:          "假因果"
        case .equivocation:        "歧义谬误"
        case .appealToTradition:   "诉诸传统"
        case .bandwagon:           "从众谬误"
        case .noFallacy:           "无谬误"
        }
    }

    var description: String {
        switch self {
        case .adHominem:           "攻击提出论证的人，而非论证本身"
        case .strawMan:            "歪曲对方观点后加以反驳"
        case .falseDisjunction:    "只给出两个选项，忽略其他可能性"
        case .slipperySlope:       "声称一个行动将不可避免地导致极端后果"
        case .appealToAuthority:   "以权威人士的意见代替证据"
        case .appealToEmotion:     "用情感取代逻辑论证"
        case .hastyGeneralization: "从少量样本得出普遍结论"
        case .circularReasoning:   "结论已经隐含在前提之中"
        case .redHerring:          "引入无关话题转移注意力"
        case .falseCause:          "错误地将相关性当作因果关系"
        case .equivocation:        "在论证中改变关键词的含义"
        case .appealToTradition:   "因为一直这样做所以是正确的"
        case .bandwagon:           "因为大家都这么做所以是正确的"
        case .noFallacy:           "论证中不存在逻辑谬误"
        }
    }
}

// MARK: - Fallacy Detection

struct FallacyDetectionItem: Codable, Identifiable, Equatable {
    let id: String
    let argumentText: String
    let correctFallacy: LogicalFallacy
    let distractors: [LogicalFallacy]
    let explanation: String

    var allOptions: [LogicalFallacy] {
        ([correctFallacy] + distractors).shuffled()
    }
}

// MARK: - Argument Evaluation

enum ArgumentModifierType: String, Codable, CaseIterable, Identifiable {
    case strengthen
    case weaken
    case irrelevant

    var id: String { rawValue }

    var label: String {
        switch self {
        case .strengthen:  "加强"
        case .weaken:      "削弱"
        case .irrelevant:  "无关"
        }
    }
}

struct ArgumentModifier: Codable, Identifiable, Equatable {
    let id: String
    let text: String
    let type: ArgumentModifierType
    let explanation: String
}

struct ArgumentEvaluationItem: Codable, Identifiable, Equatable {
    let id: String
    let argumentText: String
    let hiddenAssumption: String
    let assumptionOptions: [String]
    let correctAssumptionIndex: Int
    let modifierStatements: [ArgumentModifier]
}

// MARK: - Logic Argument Passage

struct LogicArgumentPassage: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let domainTag: String
    let difficulty: Int
    let body: String
    let argumentComponents: [ArgumentComponent]
    let fallacyItems: [FallacyDetectionItem]
    let evaluationItems: [ArgumentEvaluationItem]

    var requiresEvaluation: Bool { difficulty >= 2 }
}

// MARK: - Metrics

struct LogicArgumentMetrics: Codable, Equatable {
    var passageID: String
    var difficulty: Int

    // Phase 1: 结构标注
    var componentTotal: Int
    var componentCorrect: Int
    var componentAccuracy: Double

    // Phase 2: 谬误侦测
    var fallacyTotal: Int
    var fallacyCorrect: Int
    var fallacyAccuracy: Double

    // Phase 3: 论证评估
    var assumptionCorrect: Bool
    var modifierTotal: Int
    var modifierCorrect: Int
    var modifierAccuracy: Double

    var responseDuration: TimeInterval

    var compositeScore: Double {
        let evalScore = (assumptionCorrect ? 0.5 : 0.0) + modifierAccuracy * 0.5
        return componentAccuracy * 0.30 + fallacyAccuracy * 0.35 + evalScore * 0.35
    }
}

// MARK: - Library

enum LogicArgumentPassageLibrary {
    private static let bundled: [LogicArgumentPassage] = loadPassages()

    static var all: [LogicArgumentPassage] {
        // Future: merge with Materials pipeline approved passages
        bundled
    }

    static func randomPassage(difficulty: Int) -> LogicArgumentPassage? {
        let candidates = all.filter { $0.difficulty == difficulty }
        return candidates.randomElement()
    }

    static func nextPassage(difficulty: Int, excludingID: String? = nil) -> LogicArgumentPassage {
        let candidates = all.filter { $0.difficulty == difficulty && $0.id != excludingID }
        if let selected = candidates.randomElement() {
            return selected
        }
        let fallback = all.filter { $0.difficulty == difficulty }
        if let selected = fallback.randomElement() {
            return selected
        }
        return all.min(by: { abs($0.difficulty - difficulty) < abs($1.difficulty - difficulty) }) ?? all[0]
    }

    private static func loadPassages() -> [LogicArgumentPassage] {
        guard let url = locateResource(named: "logic_argument_passages", extension: "json") else {
            // Gracefully return empty if not yet bundled during development
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([LogicArgumentPassage].self, from: data)
        } catch {
            return []
        }
    }

    private static func locateResource(named name: String, extension ext: String) -> URL? {
        let bundles = [Bundle.main, Bundle(for: BundleMarker.self)] + Bundle.allBundles
        let fileName = "\(name).\(ext)"
        for bundle in bundles {
            if let direct = bundle.url(forResource: name, withExtension: ext) {
                return direct
            }
            if let direct = bundle.url(forResource: name, withExtension: ext, subdirectory: "Reading") {
                return direct
            }
            if let direct = bundle.url(forResource: name, withExtension: ext, subdirectory: "Resources/Reading") {
                return direct
            }
            if let found = recursiveSearch(in: bundle.resourceURL, target: fileName) {
                return found
            }
        }
        return nil
    }

    private static func recursiveSearch(in directory: URL?, target: String) -> URL? {
        guard let directory else { return nil }
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        while let next = enumerator?.nextObject() as? URL {
            if next.lastPathComponent == target { return next }
        }
        return nil
    }

    private final class BundleMarker {}
}

// MARK: - Validation (for Materials pipeline)

enum LogicArgumentValidation {
    static func validate(_ passage: LogicArgumentPassage) -> [String] {
        var issues: [String] = []

        if passage.argumentComponents.count < 3 {
            issues.append("论证组件不足3个（当前\(passage.argumentComponents.count)个）")
        }
        if !passage.argumentComponents.contains(where: { $0.role == .conclusion }) {
            issues.append("缺少结论组件")
        }
        if !passage.argumentComponents.contains(where: { $0.role == .premise }) {
            issues.append("缺少前提组件")
        }
        if passage.body.count < 100 {
            issues.append("论证正文过短（\(passage.body.count)字）")
        }
        for item in passage.fallacyItems {
            if item.distractors.count != 3 {
                issues.append("谬误题 \(item.id) 干扰项应为3个（当前\(item.distractors.count)个）")
            }
        }
        for item in passage.evaluationItems {
            if item.assumptionOptions.count != 4 {
                issues.append("评估题 \(item.id) 假设选项应为4个（当前\(item.assumptionOptions.count)个）")
            }
            if !item.assumptionOptions.indices.contains(item.correctAssumptionIndex) {
                issues.append("评估题 \(item.id) 正确选项索引越界")
            }
        }
        if passage.difficulty >= 2 && passage.evaluationItems.isEmpty {
            issues.append("难度2+必须包含至少1道评估题")
        }

        return issues
    }
}

// MARK: - Consistency Check Result (for Materials pipeline)

struct ConsistencyCheckResult: Codable {
    var structureAgreement: Double
    var fallacyAgreement: Bool
    var assumptionAgreement: Bool
    var disagreementDetails: [String]

    var isHighConfidence: Bool {
        structureAgreement >= 0.8 && fallacyAgreement && assumptionAgreement
    }
}
