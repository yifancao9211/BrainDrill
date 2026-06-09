import Foundation

enum AdaptiveBlockOutcome: String, Codable, Equatable {
    case promote
    case stay
    case demote
}

enum SkillCategory: String, Codable, CaseIterable, Identifiable {
    case readingComprehension
    case logicalReasoning
    case memory
    case visualAttentionSearch

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .readingComprehension:
            "阅读理解"
        case .logicalReasoning:
            "逻辑推理"
        case .memory:
            "记忆"
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

/// 单模块的科学能力估计：θ（0–100，已展示能力）+ 可信度（随训练量上升）。
struct ModuleSkillEstimate: Equatable, Identifiable {
    let module: TrainingModule
    let theta: Double          // 0–100
    let reliability: Double     // 0–1
    let sessions: Int

    var hasData: Bool { sessions > 0 }
    var id: TrainingModule { module }
}

struct CategorySkillScore: Equatable, Identifiable {
    let category: SkillCategory
    let score: Double           // 已训练模块按可信度加权的 θ（无数据时为 0）
    let reliability: Double      // 0–1：综合可信度（含覆盖率）
    let trainedCount: Int        // 已训练模块数
    let totalCount: Int          // 该维度模块总数

    var hasData: Bool { trainedCount > 0 }
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
    let moduleEstimates: [TrainingModule: ModuleSkillEstimate]
    let categoryScores: [CategorySkillScore]      // 全部四个维度，含「无数据」标记
    let overallInternalScore: Double               // 有数据维度按可信度加权（0 表示无数据）
    let overallConfidence: Double                  // 0–1
    let coverage: Double                           // 有数据维度数 / 4

    /// 科学版：直接从训练记录计算（不再依赖被 35 默认值污染的状态平均）。
    static func compute(sessions: [SessionResult]) -> AppSkillProfile {
        // 1) 每个模块：近因加权 θ + 可信度。
        let byModule = Dictionary(grouping: sessions.filter { TrainingModule.allCases.contains($0.module) }, by: \.module)
        var estimates: [TrainingModule: ModuleSkillEstimate] = [:]
        for module in TrainingModule.allCases {
            estimates[module] = SkillEstimator.estimate(module: module, sessions: byModule[module] ?? [])
        }

        // 2) 维度：仅对「已训练」模块按可信度加权；可信度含覆盖率。
        let categoryScores = SkillCategory.allCases.map { category -> CategorySkillScore in
            let modules = TrainingModule.allCases.filter { $0.skillCategory == category }
            let trained = modules.compactMap { estimates[$0] }.filter { $0.hasData }
            let relSum = trained.map(\.reliability).reduce(0, +)
            let score = relSum > 0 ? trained.map { $0.theta * $0.reliability }.reduce(0, +) / relSum : 0
            // 可信度 = Σ可信度 / 模块总数：既看练得准不准，也看覆盖了几个。
            let reliability = modules.isEmpty ? 0 : min(1, relSum / Double(modules.count))
            return CategorySkillScore(
                category: category,
                score: min(max(score, 0), 100),
                reliability: reliability,
                trainedCount: trained.count,
                totalCount: modules.count
            )
        }

        // 3) 综合：有数据维度按可信度加权（不再硬打折，覆盖率单独呈现）。
        let dataCategories = categoryScores.filter { $0.hasData }
        let relSum = dataCategories.map(\.reliability).reduce(0, +)
        let overall = relSum > 0 ? dataCategories.map { $0.score * $0.reliability }.reduce(0, +) / relSum : 0
        let overallConfidence = dataCategories.isEmpty ? 0 : dataCategories.map(\.reliability).reduce(0, +) / Double(dataCategories.count)
        let coverage = Double(dataCategories.count) / Double(SkillCategory.allCases.count)

        return AppSkillProfile(
            moduleEstimates: estimates,
            categoryScores: categoryScores,
            overallInternalScore: min(max(overall, 0), 100),
            overallConfidence: min(max(overallConfidence, 0), 1),
            coverage: coverage
        )
    }
}

/// 科学能力估计器：把每次训练映射到 0–100 的能力 θ，再做近因加权与可信度。
enum SkillEstimator {
    static let criterion = 0.72        // 目标正确率（达到即视为掌握当前档位）
    static let levelsPerUnit = 2.5     // 正确率每偏离基准 1.0，折算成的档位偏移系数
    static let recencyDecay = 0.85     // 近因衰减
    static let recencyWindow = 8       // 仅看最近 N 次
    static let priorStrength = 4.0     // 可信度 n/(n+k) 的 k

    /// 单次训练的能力 θ（0–100）：以「打到的档位」为基准，按本次正确率相对基准的偏离上下浮动。
    static func sessionTheta(module: TrainingModule, level: Int, performance: Double) -> Double {
        let range = module.adaptiveLevelRange
        let span = Double(max(1, range.upperBound - range.lowerBound))
        let ladder = module.normalizedLevel(level)                 // 0–1：档位在该模块阶梯上的位置
        let shiftLevels = (performance - criterion) * levelsPerUnit  // 正→能力高于当前档，负→低于
        let frac = min(max(ladder + shiftLevels / span, 0), 1)
        return frac * 100
    }

    static func estimate(module: TrainingModule, sessions: [SessionResult]) -> ModuleSkillEstimate {
        let n = sessions.count
        guard n > 0 else {
            return ModuleSkillEstimate(module: module, theta: 0, reliability: 0, sessions: 0)
        }
        // 取最近若干次（sessions 已按 endedAt 降序）做近因加权平均。
        let recent = Array(sessions.prefix(recencyWindow))
        var weightSum = 0.0
        var thetaSum = 0.0
        for (i, session) in recent.enumerated() {
            let w = pow(recencyDecay, Double(i))
            let level = AdaptiveScoring.nextRecommendedLevel(for: session)
            let perf = AdaptiveScoring.performanceIndex(for: session)
            thetaSum += w * sessionTheta(module: module, level: level, performance: perf)
            weightSum += w
        }
        let theta = weightSum > 0 ? thetaSum / weightSum : 0
        let reliability = Double(n) / (Double(n) + priorStrength)
        return ModuleSkillEstimate(module: module, theta: theta, reliability: reliability, sessions: n)
    }
}
