import Foundation

enum AdaptiveBlockOutcome: String, Codable, Equatable {
    case promote
    case stay
    case demote
}

enum SkillCategory: String, Codable, CaseIterable, Identifiable {
    case readingComprehension
    case memory
    case reactionSpeed
    case inhibitionControl
    case visualAttentionSearch

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .readingComprehension:
            "阅读理解"
        case .memory:
            "记忆"
        case .reactionSpeed:
            "反应速度"
        case .inhibitionControl:
            "抑制控制"
        case .visualAttentionSearch:
            "视觉注意/搜索"
        }
    }
}

struct ModuleAdaptiveState: Codable, Equatable {
    var currentLevel: Int
    var internalSkillScore: Double
    var confidence: Double
    var recentTrend: Double
    var sessionsPlayed: Int
    var lastSessionPerformanceIndex: Double
    var recommendedStartLevel: Int

    static func `default`(for module: TrainingModule) -> ModuleAdaptiveState {
        let level = module.defaultAdaptiveLevel
        return ModuleAdaptiveState(
            currentLevel: level,
            internalSkillScore: 35,
            confidence: 0,
            recentTrend: 0,
            sessionsPlayed: 0,
            lastSessionPerformanceIndex: 0,
            recommendedStartLevel: level
        )
    }
}

struct CategorySkillScore: Equatable, Identifiable {
    let category: SkillCategory
    let score: Double
    let confidence: Double
    let moduleCount: Int

    var id: SkillCategory { category }
}

struct NormativeLayer: Equatable {
    let percentile: Double?
    let zScore: Double?
    let referencePopulation: String?
    let sampleSize: Int?

    static let unavailable = NormativeLayer(
        percentile: nil,
        zScore: nil,
        referencePopulation: nil,
        sampleSize: nil
    )
}

struct AppSkillProfile: Equatable {
    let moduleScores: [TrainingModule: ModuleAdaptiveState]
    let categoryScores: [CategorySkillScore]
    let overallInternalScore: Double
    let overallConfidence: Double
    let normativeLayer: NormativeLayer

    static func compute(from states: [TrainingModule: ModuleAdaptiveState]) -> AppSkillProfile {
        let mergedStates = TrainingModule.allCases.reduce(into: [TrainingModule: ModuleAdaptiveState]()) { partial, module in
            partial[module] = states[module] ?? .default(for: module)
        }

        let categoryScores = SkillCategory.allCases.map { category in
            let modules = mergedStates.filter { $0.key.skillCategory == category }
            let count = modules.count
            guard count > 0 else {
                return CategorySkillScore(category: category, score: 0, confidence: 0, moduleCount: 0)
            }

            let averageScore = modules.values.map(\.internalSkillScore).reduce(0, +) / Double(count)
            let averageConfidence = modules.values.map(\.confidence).reduce(0, +) / Double(count)
            return CategorySkillScore(
                category: category,
                score: averageScore,
                confidence: averageConfidence,
                moduleCount: count
            )
        }

        let coveredCategories = categoryScores.filter { $0.score > 0 }
        let rawOverall = coveredCategories.isEmpty
            ? 0
            : coveredCategories.map(\.score).reduce(0, +) / Double(coveredCategories.count)
        let overallConfidence = coveredCategories.isEmpty
            ? 0
            : coveredCategories.map(\.confidence).reduce(0, +) / Double(coveredCategories.count)
        let coverage = Double(coveredCategories.count) / Double(SkillCategory.allCases.count)
        let adjustedOverall = rawOverall * (0.55 + 0.45 * coverage)

        return AppSkillProfile(
            moduleScores: mergedStates,
            categoryScores: categoryScores,
            overallInternalScore: min(max(adjustedOverall, 0), 100),
            overallConfidence: min(max(overallConfidence, 0), 1),
            normativeLayer: .unavailable
        )
    }
}
