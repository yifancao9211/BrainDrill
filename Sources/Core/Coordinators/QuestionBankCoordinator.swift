import Foundation
import Observation

/// 题库练习协调器。一个实例代表一个模块（逻辑推理 / 考公），
/// 用默认板块范围(scope)初始化；可在 `startSession` 时临时指定板块与题型。
/// 负责会话生命周期、跨会话弱项统计与近期去重（UserDefaults 持久化）。
@Observable
final class QuestionBankCoordinator: TrainingModuleCoordinator {
    let module: TrainingModule
    /// 默认板块范围。逻辑推理 = `[.logicReasoning]`；考公 = 全部行测板块。
    let defaultSections: [BankSection]

    var engine: QuestionBankEngine?
    var lastResult: SessionResult?
    var statusMessage: String

    /// 从 AppModel 注入的已导入题（与内置题合并）。
    var importedQuestions: [BankQuestion] = []

    /// 当前会话的板块/题型（用于结算与统计 key）。
    private(set) var activeSection: BankSection?
    private(set) var activeType: String?
    private(set) var sessionConditions = SessionConditions()
    private(set) var sessionsCompleted: Int = 0

    var isActive: Bool { engine != nil && !(engine?.isComplete ?? true) }

    init(module: TrainingModule, defaultSections: [BankSection], statusMessage: String) {
        self.module = module
        self.defaultSections = defaultSections
        self.statusMessage = statusMessage
    }

    // MARK: - Persistent state (UserDefaults, keyed per-module)

    private var typeStatsKey: String { "qbank_\(module.rawValue)_type_stats" }
    private var recentKey: String { "qbank_\(module.rawValue)_recent" }
    private static let recentCap = 60

    var typeStats: [String: BankTypeStats] {
        get {
            guard let data = UserDefaults.standard.data(forKey: typeStatsKey),
                  let decoded = try? JSONDecoder().decode([String: BankTypeStats].self, from: data) else {
                return [:]
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: typeStatsKey)
            }
        }
    }

    var recentFingerprints: [String] {
        get { UserDefaults.standard.stringArray(forKey: recentKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: recentKey) }
    }

    /// 逐题作答统计（轻量 IRT 的经验难度来源）：题 id → 做对率统计。
    private var questionStatsKey: String { "qbank_\(module.rawValue)_q_stats" }
    var questionStats: [String: BankTypeStats] {
        get {
            guard let data = UserDefaults.standard.data(forKey: questionStatsKey),
                  let decoded = try? JSONDecoder().decode([String: BankTypeStats].self, from: data) else { return [:] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: questionStatsKey)
            }
        }
    }

    /// 经验难度（1–3）：做对率越低越难，并按作答次数与作者标注难度做可信度加权融合。
    func effectiveDifficulties(for pool: [BankQuestion]) -> [String: Double] {
        let stats = questionStats
        var map: [String: Double] = [:]
        for q in pool {
            guard let s = stats[q.id], s.totalAttempts > 0 else { continue }
            let empirical = 1 + (1 - s.accuracy) * 2            // 做对率 1→1，0→3
            let w = Double(s.totalAttempts) / (Double(s.totalAttempts) + 4)
            map[q.id] = Double(q.difficulty) * (1 - w) + empirical * w
        }
        return map
    }

    // MARK: - Queries

    /// 内置 + 已导入题中实际有内容的板块（限定在本模块默认范围内）。
    var availableSections: [BankSection] {
        let all = QuestionBankLibrary.mergedQuestions(imported: importedQuestions)
        return defaultSections.filter { section in all.contains { $0.section == section } }
    }

    func availableTypes(in section: BankSection) -> [String] {
        QuestionBankLibrary.types(in: section, imported: importedQuestions)
    }

    func weakTypes(in sections: [BankSection]) -> [String] {
        let stats = typeStats
        let typeUniverse = sections.flatMap { availableTypes(in: $0) }
        return typeUniverse.filter { stats[$0]?.isWeak == true }
    }

    // MARK: - Session lifecycle

    func startSession(
        sections: [BankSection]? = nil,
        type: String? = nil,
        count: Int = 10,
        timed: Bool = false,
        totalSeconds: Int = 600,
        startDifficulty: Double = 1.5
    ) {
        let scope = (sections?.isEmpty == false ? sections! : availableSectionsOrDefault())
        let allInScope = QuestionBankLibrary.questions(in: scope, type: type, imported: importedQuestions)
        guard !allInScope.isEmpty else {
            statusMessage = "该范围暂无题目，请先导入题库。"
            return
        }
        // 近期去重：新题足够就排除近期出现过的，保留全部难度供阶梯升降。
        let recent = Set(recentFingerprints)
        let fresh = allInScope.filter { !recent.contains($0.fingerprint) }
        let pool = fresh.count >= count ? fresh : allInScope

        activeSection = scope.first ?? pool.first?.section ?? .logicReasoning
        activeType = type
        engine = QuestionBankEngine(
            pool: pool,
            section: activeSection ?? .logicReasoning,
            targetCount: count,
            startDifficulty: startDifficulty,
            weakTypes: Set(weakTypes(in: scope)),
            difficultyOverrides: effectiveDifficulties(for: pool),
            sectionWeights: Dictionary(uniqueKeysWithValues: scope.map { ($0, $0.examWeight) }),
            timed: timed,
            totalSeconds: totalSeconds
        )
        lastResult = nil
        sessionConditions = SessionConditions(
            feedbackEnabled: true,
            adaptiveEnabled: true,
            customParameters: ["startDifficulty": String(format: "%.1f", startDifficulty)]
        )
        statusMessage = timed ? "模考进行中，注意总时间。" : "逐题作答，难度按表现自适应。"
    }

    // MARK: - 错题复习

    /// 给定板块范围内、到期待复习的错题数。
    func dueReviewCount(in sections: [BankSection]) -> Int {
        let due = ReviewStore.dueIDs()
        guard !due.isEmpty else { return 0 }
        return QuestionBankLibrary.questions(in: sections, type: nil, imported: importedQuestions)
            .filter { due.contains($0.id) }.count
    }

    /// 开始一场错题复习：只出该范围内到期的错题，全部过一遍。
    func startReview(in sections: [BankSection]) {
        let due = ReviewStore.dueIDs()
        let pool = QuestionBankLibrary.questions(in: sections, type: nil, imported: importedQuestions)
            .filter { due.contains($0.id) }
        guard !pool.isEmpty else {
            statusMessage = "暂无到期的错题。"
            return
        }
        activeSection = sections.first ?? pool.first?.section ?? .logicReasoning
        activeType = nil
        engine = QuestionBankEngine(
            pool: pool,
            section: activeSection ?? .logicReasoning,
            targetCount: pool.count,
            startDifficulty: 1.5,
            weakTypes: Set(weakTypes(in: sections)),
            difficultyOverrides: effectiveDifficulties(for: pool)
        )
        lastResult = nil
        sessionConditions = SessionConditions(feedbackEnabled: true, adaptiveEnabled: false, customParameters: ["mode": "review"])
        statusMessage = "错题复习：把做错的题再过一遍。"
    }

    private func availableSectionsOrDefault() -> [BankSection] {
        let available = availableSections
        return available.isEmpty ? defaultSections : available
    }

    /// 用户作答（直接转交引擎，便于 View 调用）。
    func select(_ optionIndex: Int, at date: Date = Date()) {
        engine?.select(optionIndex, at: date)
    }

    func advance(at date: Date = Date()) {
        engine?.advance(at: date)
    }

    func forceComplete() {
        engine?.forceComplete()
    }

    func finalizeIfComplete() -> SessionResult? {
        guard let engine, engine.isComplete else { return nil }
        return buildResult(from: engine)
    }

    func cancelSession() {
        engine = nil
        activeSection = nil
        activeType = nil
        statusMessage = "已取消题库练习。"
    }

    // MARK: - Private

    private func buildResult(from engine: QuestionBankEngine) -> SessionResult {
        let metrics = engine.computeMetrics()
        let now = Date()

        var conditions = sessionConditions
        conditions.customParameters["section"] = (activeSection ?? metrics.section).rawValue
        conditions.customParameters["finalLevel"] = "\(metrics.difficulty)"

        let result = SessionResult(
            module: module,
            startedAt: engine.startedAt,
            endedAt: now,
            duration: now.timeIntervalSince(engine.startedAt),
            metrics: .questionBank(metrics),
            conditions: conditions
        )

        lastResult = result
        sessionsCompleted += 1

        // 记录近期出现的题，未来会话尽量避开。
        var recent = recentFingerprints + engine.answers.map { $0.question.fingerprint }
        if recent.count > Self.recentCap {
            recent.removeFirst(recent.count - Self.recentCap)
        }
        recentFingerprints = recent

        // 更新题型统计（弱项加权）。
        var stats = typeStats
        for answer in engine.answers {
            var stat = stats[answer.question.type] ?? BankTypeStats()
            stat.record(correct: answer.isCorrect)
            stats[answer.question.type] = stat
        }
        typeStats = stats

        // 更新逐题作答统计（经验难度来源）。
        var qStats = questionStats
        for answer in engine.answers {
            var stat = qStats[answer.question.id] ?? BankTypeStats()
            stat.record(correct: answer.isCorrect)
            qStats[answer.question.id] = stat
        }
        questionStats = qStats

        // 错题本 + 间隔重复：错题入库、复习对题推进。
        ReviewStore.record(engine.answers.map { ($0.question.id, $0.isCorrect) })

        statusMessage = "练习完成 — 正确率 \(String(format: "%.0f", metrics.accuracy * 100))%"
        self.engine = nil
        return result
    }
}
