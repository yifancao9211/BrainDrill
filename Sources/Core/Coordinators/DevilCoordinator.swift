import Foundation
import Observation

/// 魔鬼锻炼 hub 协调器：一个模块(`.devilTraining`)统管多个限时小游戏
/// （魔鬼计算 / 魔鬼翻牌 / 魔鬼抓鼠）。结果统一为 `DevilGameMetrics`。
@Observable
final class DevilCoordinator: TrainingModuleCoordinator {
    var activeGame: DevilGameKind?
    var calcEngine: DevilCalcEngine?
    var flipEngine: DevilFlipEngine?
    var mouseEngine: DevilMouseEngine?
    var lastResult: SessionResult?
    var statusMessage: String = "魔鬼锻炼：限时高压，连击越高分越多。"
    /// 上一局是否打破该游戏的个人最佳。
    private(set) var lastWasRecord: Bool = false

    // MARK: - 长期成长状态（@Observable，UserDefaults 持久化）

    private(set) var totalPower: Int = 0                       // 累计魔力值（历史总得分）
    private(set) var unlockedAchievements: Set<String> = []
    private(set) var gamesPlayed: Set<DevilGameKind> = []
    private(set) var starsByGame: [DevilGameKind: Int] = [:]
    private(set) var dailyKind: DevilDailyKind = .score
    private(set) var dailyProgress: Int = 0
    private(set) var dailyDone: Bool = false

    // 魔鬼连续天数（独立于主界面打卡；"连续玩魔鬼锻炼"的天数）。
    private(set) var currentStreak: Int = 0
    private(set) var bestStreak: Int = 0
    private(set) var totalSessions: Int = 0

    // 上一局的结算附加结果（供结算页展示）。
    private(set) var lastRunStars: Int = 0
    private(set) var lastUnlocked: [DevilAchievement] = []
    private(set) var lastRankUp: DevilRank?
    private(set) var lastDailyJustCompleted: Bool = false
    private(set) var lastWasPeakRecord: Bool = false   // 上一局是否刷新峰值档位记录

    var rank: DevilRank { DevilRank.forPower(totalPower) }

    /// 今日是否已玩过魔鬼锻炼。
    var todayStamped: Bool { UserDefaults.standard.string(forKey: "devil_last_played") == Self.todayKey() }

    /// 某游戏的历史峰值档位记录。
    func bestPeakLevel(for kind: DevilGameKind) -> Int {
        UserDefaults.standard.integer(forKey: "devil_bestN_\(kind.rawValue)")
    }

    init() { loadProgress() }

    /// 某游戏的历史最佳分（UserDefaults 持久化）。
    func bestScore(for kind: DevilGameKind) -> Int {
        UserDefaults.standard.integer(forKey: "devil_best_\(kind.rawValue)")
    }

    func stars(for kind: DevilGameKind) -> Int { starsByGame[kind] ?? 0 }

    /// 已实现（可玩）的小游戏。
    static let availableGames: Set<DevilGameKind> = [.calc, .flip, .mouse]

    private var activeEngine: (any DevilGameEngine)? {
        if let calcEngine { return calcEngine }
        if let flipEngine { return flipEngine }
        if let mouseEngine { return mouseEngine }
        return nil
    }

    var isActive: Bool {
        guard let engine = activeEngine else { return false }
        return !engine.isComplete
    }

    func isPlayable(_ kind: DevilGameKind) -> Bool { Self.availableGames.contains(kind) }

    /// `memoryTheta`：记忆维度能力 θ（0–100），用来决定本局可达到的档位上限。
    func startGame(_ kind: DevilGameKind, adaptiveState: ModuleAdaptiveState, memoryTheta: Double = 100) {
        guard isPlayable(kind) else {
            statusMessage = "「\(kind.displayName)」即将开放。"
            return
        }
        clearEngines()
        lastResult = nil
        activeGame = kind
        let start = adaptiveState.recommendedStartLevel
        // 档位上限随 θ 提升：θ0 约半程，θ100 解锁满档；至少 3 档保证可玩。
        let frac = min(max(memoryTheta / 100, 0), 1)
        let cap = min(max(Int((Double(kind.maxLevel) * (0.5 + 0.5 * frac)).rounded()), 3), kind.maxLevel)
        switch kind {
        case .calc:  calcEngine = DevilCalcEngine(startLevel: start, levelCap: cap)
        case .flip:  flipEngine = DevilFlipEngine(startLevel: start, levelCap: cap)
        case .mouse: mouseEngine = DevilMouseEngine(startLevel: start, levelCap: cap)
        }
        statusMessage = "\(kind.displayName)进行中，注意时间！"
    }

    /// 计时耗尽：结束当前小游戏。
    func timeUp() {
        activeEngine?.finish()
    }

    func finalizeIfComplete() -> SessionResult? {
        guard let kind = activeGame, let engine = activeEngine, engine.isComplete else { return nil }
        let metrics = DevilGameMetrics(
            game: kind,
            durationSeconds: engine.totalSeconds,
            attempted: engine.attempted,
            correct: engine.correct,
            accuracy: engine.accuracy,
            maxCombo: engine.maxCombo,
            peakLevel: engine.peakLevel,
            score: engine.score
        )
        let now = Date()
        let result = SessionResult(
            module: .devilTraining,
            startedAt: engine.startedAt,
            endedAt: now,
            duration: now.timeIntervalSince(engine.startedAt),
            metrics: .devilGame(metrics),
            conditions: SessionConditions(adaptiveEnabled: true, customParameters: ["finalLevel": "\(engine.peakLevel)"])
        )
        // 个人最佳与破纪录判定。
        lastWasRecord = metrics.score > bestScore(for: kind)
        if lastWasRecord {
            UserDefaults.standard.set(metrics.score, forKey: "devil_best_\(kind.rawValue)")
        }
        // 峰值档位记录。
        lastWasPeakRecord = metrics.peakLevel > bestPeakLevel(for: kind)
        if lastWasPeakRecord {
            UserDefaults.standard.set(metrics.peakLevel, forKey: "devil_bestN_\(kind.rawValue)")
        }

        applyProgress(kind: kind, metrics: metrics)

        lastResult = result
        clearEngines()
        activeGame = nil
        statusMessage = "\(kind.displayName)完成 — 得分 \(metrics.score)\(lastWasRecord ? "（新纪录！）" : "")"
        return result
    }

    // MARK: - Progression

    private func applyProgress(kind: DevilGameKind, metrics: DevilGameMetrics) {
        let grade = DevilGrade.evaluate(accuracy: metrics.accuracy, peakLevel: metrics.peakLevel, maxLevel: kind.maxLevel)

        // 星级
        lastRunStars = grade.stars
        starsByGame[kind, default: 0] += grade.stars

        // 段位（魔力值）
        let rankBefore = DevilRank.forPower(totalPower)
        totalPower += metrics.score
        let rankAfter = DevilRank.forPower(totalPower)
        lastRankUp = rankAfter != rankBefore ? rankAfter : nil

        // 玩过的游戏
        gamesPlayed.insert(kind)

        // 累计局数
        totalSessions += 1

        // 魔鬼连续天数
        updateStreak()

        // 每日挑战
        refreshDailyIfNeeded()
        let wasDone = dailyDone
        switch dailyKind {
        case .score:    dailyProgress += metrics.score
        case .combo:    dailyProgress = max(dailyProgress, metrics.maxCombo)
        case .sessions: dailyProgress += 1
        }
        dailyDone = dailyProgress >= dailyKind.target
        lastDailyJustCompleted = dailyDone && !wasDone

        // 成就
        lastUnlocked = evaluateAchievements(kind: kind, metrics: metrics, grade: grade)

        saveProgress()
    }

    private func evaluateAchievements(kind: DevilGameKind, metrics: DevilGameMetrics, grade: DevilGrade) -> [DevilAchievement] {
        var newly: [DevilAchievement] = []
        func unlock(_ id: String) {
            guard !unlockedAchievements.contains(id), let a = DevilAchievement.by(id: id) else { return }
            unlockedAchievements.insert(id)
            newly.append(a)
        }
        unlock("devil-first")
        if metrics.maxCombo >= 10 { unlock("devil-combo10") }
        if kind == .calc && grade == .S { unlock("devil-calc-s") }
        if gamesPlayed.count >= DevilGameKind.allCases.count { unlock("devil-allgames") }
        if rank.rawValue >= DevilRank.demon.rawValue { unlock("devil-rank-demon") }
        if rank.rawValue >= DevilRank.overlord.rawValue { unlock("devil-rank-overlord") }
        if kind == .calc && metrics.peakLevel >= DevilGameKind.calc.maxLevel { unlock("devil-calc-n4") }
        if kind == .flip && metrics.peakLevel >= DevilGameKind.flip.maxLevel { unlock("devil-flip-max") }
        if kind == .mouse && metrics.peakLevel >= DevilGameKind.mouse.maxLevel { unlock("devil-mouse-max") }
        if currentStreak >= 7 { unlock("devil-streak7") }
        if currentStreak >= 30 { unlock("devil-streak30") }
        if totalSessions >= 50 { unlock("devil-sessions50") }
        return newly
    }

    /// 更新魔鬼连续天数：今天已记不变；昨天 +1；否则重置为 1。
    private func updateStreak() {
        let today = Self.todayKey()
        let last = UserDefaults.standard.string(forKey: "devil_last_played")
        if last == today {
            // 今天已玩过，连续天数不变
        } else if last == Self.todayKey(Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: Date()) ?? Date()) {
            currentStreak += 1
        } else {
            currentStreak = 1
        }
        bestStreak = max(bestStreak, currentStreak)
        UserDefaults.standard.set(today, forKey: "devil_last_played")
    }

    // MARK: - Persistence

    private static func todayKey(_ now: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: now)
    }

    private func refreshDailyIfNeeded() {
        let today = Self.todayKey()
        let storedDate = UserDefaults.standard.string(forKey: "devil_daily_date")
        if storedDate != today {
            UserDefaults.standard.set(today, forKey: "devil_daily_date")
            dailyKind = DevilDailyKind.forDateKey(today)
            dailyProgress = 0
            dailyDone = false
        } else {
            dailyKind = DevilDailyKind.forDateKey(today)
        }
    }

    private func loadProgress() {
        let d = UserDefaults.standard
        totalPower = d.integer(forKey: "devil_power")
        unlockedAchievements = Set(d.stringArray(forKey: "devil_ach") ?? [])
        gamesPlayed = Set((d.stringArray(forKey: "devil_games_played") ?? []).compactMap(DevilGameKind.init(rawValue:)))
        for kind in DevilGameKind.allCases {
            starsByGame[kind] = d.integer(forKey: "devil_stars_\(kind.rawValue)")
        }
        refreshDailyIfNeeded()
        dailyProgress = d.integer(forKey: "devil_daily_progress")
        dailyDone = d.bool(forKey: "devil_daily_done")
        currentStreak = d.integer(forKey: "devil_streak")
        bestStreak = d.integer(forKey: "devil_best_streak")
        totalSessions = d.integer(forKey: "devil_total_sessions")
    }

    private func saveProgress() {
        let d = UserDefaults.standard
        d.set(totalPower, forKey: "devil_power")
        d.set(Array(unlockedAchievements), forKey: "devil_ach")
        d.set(gamesPlayed.map(\.rawValue), forKey: "devil_games_played")
        for (kind, stars) in starsByGame { d.set(stars, forKey: "devil_stars_\(kind.rawValue)") }
        d.set(dailyProgress, forKey: "devil_daily_progress")
        d.set(dailyDone, forKey: "devil_daily_done")
        d.set(currentStreak, forKey: "devil_streak")
        d.set(bestStreak, forKey: "devil_best_streak")
        d.set(totalSessions, forKey: "devil_total_sessions")
    }

    func cancelSession() {
        clearEngines()
        activeGame = nil
        statusMessage = "已退出魔鬼锻炼。"
    }

    private func clearEngines() {
        calcEngine = nil
        flipEngine = nil
        mouseEngine = nil
    }
}
