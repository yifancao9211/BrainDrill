import Foundation
import Observation

/// 魔鬼计算（视觉 N-back 算术，鬼トレ 内核）：
/// 屏幕不断出现简单算式，你要作答的是 **N 题之前**那一道的答案。`level` 即回溯深度 N。
/// 难点在记忆负荷而非计算——算式始终是个位加减。连续 3 次答对升 N、答错降 N。
@Observable
final class DevilCalcEngine: DevilGameEngine {
    struct Problem: Equatable {
        let text: String
        let answer: Int
    }

    static let maxLevel = 4
    let levelCap: Int
    let totalSeconds: Int
    let startedAt: Date

    private(set) var level: Int        // 回溯深度 N
    private(set) var peakLevel: Int
    private(set) var score: Int = 0
    private(set) var combo: Int = 0
    private(set) var maxCombo: Int = 0
    private(set) var attempted: Int = 0
    private(set) var correct: Int = 0
    private(set) var lastGain: Int = 0
    private(set) var lastAnsweredCorrectly: Bool?
    private(set) var finished: Bool = false

    /// 已展示、尚未作答的题队列（队首=最早=应答题，队尾=最新=正在记的题）。
    private(set) var pending: [Problem] = []
    /// 应答题的四选一选项（仅在有应答题时有意义；每当应答题变化时重算，避免随重绘洗牌）。
    private(set) var options: [Int] = []

    init(startLevel: Int, totalSeconds: Int = 90, levelCap: Int = .max, now: Date = Date()) {
        let cap = min(max(levelCap, 1), Self.maxLevel)
        self.levelCap = cap
        let lvl = min(max(startLevel, 1), cap)
        self.level = lvl
        self.peakLevel = lvl
        self.totalSeconds = totalSeconds
        self.startedAt = now
        self.pending = [Self.makeProblem()]
    }

    /// 当前正在展示、需要记住的最新一题。
    var current: Problem { pending.last ?? Self.makeProblem() }
    /// 应答题（N 题之前那道）：队列长度超过 N 才出现。
    var dueProblem: Problem? { pending.count > level ? pending.first : nil }
    var isAnswerDue: Bool { dueProblem != nil }

    var isComplete: Bool { finished }
    var accuracy: Double { attempted > 0 ? Double(correct) / Double(attempted) : 0 }

    // MARK: - Actions

    /// 热身/升档补记：当前没有应答题时，再展示一道新题压入队尾。
    func advanceWarmup() {
        guard !finished, !isAnswerDue else { return }
        pending.append(Self.makeProblem())
        recomputeOptions()
    }

    /// 作答 N 题之前那道题的答案。
    func answer(_ value: Int) {
        guard !finished, let due = dueProblem else { return }
        attempted += 1
        if value == due.answer {
            correct += 1
            combo += 1
            maxCombo = max(maxCombo, combo)
            lastGain = 10 * level * DevilCombo.multiplier(combo)
            score += lastGain
            lastAnsweredCorrectly = true
            if combo % 3 == 0 {
                level = min(level + 1, levelCap)
                peakLevel = max(peakLevel, level)
            }
        } else {
            combo = 0
            level = max(1, level - 1)
            lastGain = 0
            lastAnsweredCorrectly = false
        }
        // 弹出已答题，压入新题；降档后裁掉过量积压，保持队列至多 N+1。
        if !pending.isEmpty { pending.removeFirst() }
        pending.append(Self.makeProblem())
        while pending.count > level + 1 { pending.removeFirst() }
        recomputeOptions()
    }

    func finish() { finished = true }

    private func recomputeOptions() {
        if let due = dueProblem { options = Self.makeOptions(answer: due.answer) }
    }

    // MARK: - Generation

    static func makeProblem() -> Problem {
        let (text, answer) = makeExpression()
        return Problem(text: text, answer: answer)
    }

    /// 极简个位加减（不随 N 增大）——负荷来自记忆而非计算。
    private static func makeExpression() -> (String, Int) {
        if Bool.random() {
            let a = Int.random(in: 1...9), b = Int.random(in: 1...9)
            return ("\(a) + \(b)", a + b)
        } else {
            let a = Int.random(in: 1...9), b = Int.random(in: 0...a)
            return ("\(a) − \(b)", a - b)
        }
    }

    static func makeOptions(answer: Int) -> [Int] {
        var set: Set<Int> = [answer]
        var guard0 = 0
        while set.count < 4 && guard0 < 60 {
            guard0 += 1
            let delta = Int.random(in: 1...4)
            let candidate = Bool.random() ? answer + delta : answer - delta
            if candidate >= 0 { set.insert(candidate) }
        }
        var n = answer + 1
        while set.count < 4 { set.insert(n); n += 1 }
        return Array(set).shuffled()
    }
}
