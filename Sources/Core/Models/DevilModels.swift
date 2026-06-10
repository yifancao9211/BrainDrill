import Foundation

/// 连击层级与倍率：连击越高，得分倍率越高，并带名称/图标用于打击反馈。
enum DevilCombo {
    static func multiplier(_ combo: Int) -> Int {
        switch combo {
        case ..<3:  return 1
        case 3..<6: return 2
        case 6..<10: return 3
        default:    return 4
        }
    }

    /// 当前连击所处层级（普通层返回 nil，不展示横幅）。
    static func tier(_ combo: Int) -> (name: String, symbol: String)? {
        switch combo {
        case ..<3:   return nil
        case 3..<6:  return ("火热", "🔥")
        case 6..<10: return ("狂热", "⚡️")
        default:     return ("魔鬼", "👹")
        }
    }

    /// 刚跨过某个层级阈值时（3/6/10）返回该层级，用于弹出升级横幅。
    static func crossedTier(_ combo: Int) -> (name: String, symbol: String)? {
        (combo == 3 || combo == 6 || combo == 10) ? tier(combo) : nil
    }
}

/// 结算评级。基于正确率与达到的峰值档位综合评定，跨游戏通用。
/// `levelWeight`：档位在评级中的占比。魔鬼计算局内 N 固定、起步 N 低，
/// 档位权重过高会让低 N 玩家无论打多准都拿不到好评级，故 calc 用更低权重。
enum DevilGrade: String {
    case S, A, B, C, D

    static func evaluate(accuracy: Double, peakLevel: Int, maxLevel: Int, levelWeight: Double = 0.4) -> DevilGrade {
        let w = min(max(levelWeight, 0), 1)
        let levelNorm = maxLevel > 1 ? Double(peakLevel - 1) / Double(maxLevel - 1) : 0
        let perf = accuracy * (1 - w) + min(max(levelNorm, 0), 1) * w
        switch perf {
        case 0.9...:   return .S
        case 0.75..<0.9: return .A
        case 0.6..<0.75: return .B
        case 0.4..<0.6:  return .C
        default:       return .D
        }
    }

    var remark: String {
        switch self {
        case .S: "魔王附体！无懈可击。"
        case .A: "杀气十足，再进一步就是魔王。"
        case .B: "渐入佳境，保持节奏。"
        case .C: "手感尚可，再快一点、再准一点。"
        case .D: "被魔鬼吞了，再来一局复仇。"
        }
    }

    /// 本局星级：S=3⭐ A=2⭐ B=1⭐，其余 0。
    var stars: Int {
        switch self {
        case .S: 3
        case .A: 2
        case .B: 1
        case .C, .D: 0
        }
    }
}

// MARK: - 长期成长（段位 / 成就 / 每日挑战）

/// 魔鬼段位：按累计「魔力值」（历史总得分）晋升。
enum DevilRank: Int, CaseIterable, Identifiable {
    case apprentice, adept, hunter, demon, overlord, demonGod, transcendent

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .apprentice:   "见习"
        case .adept:        "学徒"
        case .hunter:       "猎手"
        case .demon:        "恶魔"
        case .overlord:     "魔王"
        case .demonGod:     "鬼神"
        case .transcendent: "超越者"
        }
    }

    var symbol: String {
        switch self {
        case .apprentice:   "🔰"
        case .adept:        "🗡️"
        case .hunter:       "🏹"
        case .demon:        "😈"
        case .overlord:     "👑"
        case .demonGod:     "🔱"
        case .transcendent: "🌌"
        }
    }

    /// 晋升到该段位所需的累计魔力值。
    var threshold: Int {
        switch self {
        case .apprentice:   0
        case .adept:        500
        case .hunter:       2000
        case .demon:        6000
        case .overlord:     15000
        case .demonGod:     40000
        case .transcendent: 100000
        }
    }

    static func forPower(_ power: Int) -> DevilRank {
        allCases.last { power >= $0.threshold } ?? .apprentice
    }

    var next: DevilRank? { DevilRank(rawValue: rawValue + 1) }
}

/// 魔鬼专属成就。
struct DevilAchievement: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let symbol: String

    static let all: [DevilAchievement] = [
        .init(id: "devil-first",       title: "首杀",     detail: "完成第一局魔鬼锻炼",     symbol: "💀"),
        .init(id: "devil-combo10",     title: "连击大师", detail: "单局达成 ×10 连击",      symbol: "⚡️"),
        .init(id: "devil-calc-s",      title: "速算狂魔", detail: "魔鬼计算拿到 S 级",      symbol: "🧮"),
        .init(id: "devil-allgames",    title: "三修",     detail: "三款小游戏都玩过",       symbol: "🎯"),
        .init(id: "devil-rank-demon",  title: "恶魔降临", detail: "段位达到「恶魔」",       symbol: "😈"),
        .init(id: "devil-calc-n4",     title: "深度大师", detail: "魔鬼计算达到 N=4",       symbol: "🧠"),
        .init(id: "devil-flip-max",    title: "翻牌满档", detail: "魔鬼翻牌达到满档",       symbol: "🃏"),
        .init(id: "devil-mouse-max",   title: "追踪满档", detail: "魔鬼抓鼠达到满档",       symbol: "🐭"),
        .init(id: "devil-streak7",     title: "七日鬼修", detail: "连续 7 天玩魔鬼锻炼",    symbol: "🔥"),
        .init(id: "devil-streak30",    title: "卅日不辍", detail: "连续 30 天玩魔鬼锻炼",   symbol: "🗓️"),
        .init(id: "devil-sessions50",  title: "百炼成钢", detail: "累计完成 50 局",         symbol: "⚔️"),
        .init(id: "devil-rank-overlord", title: "登临魔王", detail: "段位达到「魔王」",     symbol: "👑"),
    ]

    static func by(id: String) -> DevilAchievement? { all.first { $0.id == id } }
}

/// 每日魔鬼挑战。类型由日期稳定派生（无随机），每日 0 点切换。
enum DevilDailyKind: Int {
    case score, combo, sessions

    var target: Int {
        switch self {
        case .score:    500
        case .combo:    8
        case .sessions: 3
        }
    }

    var title: String {
        switch self {
        case .score:    "今日累计得分达到 500"
        case .combo:    "单局最高连击达到 ×8"
        case .sessions: "完成 3 局魔鬼锻炼"
        }
    }

    func progressText(_ progress: Int) -> String {
        switch self {
        case .combo:    "×\(progress) / ×\(target)"
        default:        "\(progress) / \(target)"
        }
    }

    /// 由“yyyy-MM-dd”日期串稳定派生当日挑战类型。
    static func forDateKey(_ key: String) -> DevilDailyKind {
        let sum = key.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return DevilDailyKind(rawValue: sum % 3) ?? .score
    }
}

/// 所有魔鬼小游戏引擎的统一读数，便于协调器以同一方式结算。
protocol DevilGameEngine: AnyObject {
    var totalSeconds: Int { get }
    var startedAt: Date { get }
    var score: Int { get }
    var attempted: Int { get }
    var correct: Int { get }
    var maxCombo: Int { get }
    var peakLevel: Int { get }
    var accuracy: Double { get }
    var isComplete: Bool { get }
    func finish()
}

/// 魔鬼锻炼的小游戏种类。魔鬼锻炼作为一个 hub 模块(`.devilTraining`)，
/// 通过 `DevilGameKind` 区分具体小游戏，结果指标共用 `DevilGameMetrics`。
enum DevilGameKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case calc    // 魔鬼计算：视觉 N-back 算术——作答 N 题之前那道的答案
    case flip    // 魔鬼翻牌：全亮预览→盖上→记忆配对
    case mouse   // 魔鬼抓鼠：看一眼老鼠藏身的格子，盖上后凭记忆点出

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .calc:  "魔鬼计算"
        case .flip:  "魔鬼翻牌"
        case .mouse: "魔鬼抓鼠"
        }
    }

    var subtitle: String {
        switch self {
        case .calc:  "记住算式，作答 N 题之前那道的答案"
        case .flip:  "牌先全亮记住，盖上后找相同数字"
        case .mouse: "记住老鼠藏在哪些格子"
        }
    }

    var systemImage: String {
        switch self {
        case .calc:  "plus.forwardslash.minus"
        case .flip:  "rectangle.on.rectangle.angled"
        case .mouse: "squareshape.split.3x3"
        }
    }

    /// 各游戏的最高档位，用于结算评级归一化。
    var maxLevel: Int {
        switch self {
        case .calc:  4
        case .flip:  6
        case .mouse: 6
        }
    }

    /// 评级中档位的权重：calc 局内 N 固定，主要看正确率；其余游戏局内升档本身就是表现。
    var gradeLevelWeight: Double {
        self == .calc ? 0.2 : 0.4
    }
}

/// 一次魔鬼锻炼小游戏的结果指标。
struct DevilGameMetrics: Codable, Equatable {
    var game: DevilGameKind
    var durationSeconds: Int
    var attempted: Int
    var correct: Int
    var accuracy: Double
    var maxCombo: Int
    var peakLevel: Int
    var score: Int

    init(
        game: DevilGameKind,
        durationSeconds: Int,
        attempted: Int,
        correct: Int,
        accuracy: Double,
        maxCombo: Int,
        peakLevel: Int,
        score: Int
    ) {
        self.game = game
        self.durationSeconds = durationSeconds
        self.attempted = attempted
        self.correct = correct
        self.accuracy = accuracy
        self.maxCombo = maxCombo
        self.peakLevel = peakLevel
        self.score = score
    }
}
