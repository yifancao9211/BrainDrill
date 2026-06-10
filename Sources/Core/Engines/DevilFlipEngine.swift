import Foundation
import Observation

/// 魔鬼翻牌：翻开盖住的牌找出数字相同的两张，匹配则消失。限时内清完一副牌即升档发新牌（牌更多）。
/// 连续匹配累积连击，匹配失败连击清零。
@Observable
final class DevilFlipEngine: DevilGameEngine {
    struct Card: Identifiable, Equatable {
        let id: Int
        let value: Int
        var faceUp: Bool = false
        var matched: Bool = false
    }

    enum Resolution { case flippedFirst, matched, mismatch, ignored }

    let totalSeconds: Int
    let startedAt: Date

    private(set) var cards: [Card] = []
    private(set) var level: Int
    private(set) var peakLevel: Int
    private(set) var score: Int = 0
    private(set) var combo: Int = 0
    private(set) var maxCombo: Int = 0
    private(set) var attempted: Int = 0   // 配对尝试次数
    private(set) var correct: Int = 0     // 成功配对数
    private(set) var boardsCleared: Int = 0
    private(set) var firstIndex: Int?
    private(set) var secondIndex: Int?
    private(set) var locked: Bool = false
    private(set) var lastGain: Int = 0
    private(set) var finished: Bool = false
    /// 预览期：发牌后所有牌正面全亮，供记忆；结束后才进入配对。
    private(set) var previewing: Bool = false

    static let maxLevel = 6
    let levelCap: Int

    init(startLevel: Int, totalSeconds: Int = 90, levelCap: Int = .max, now: Date = Date()) {
        let cap = min(max(levelCap, 1), Self.maxLevel)
        self.levelCap = cap
        let lvl = min(max(startLevel, 1), cap)
        self.level = lvl
        self.peakLevel = lvl
        self.totalSeconds = totalSeconds
        self.startedAt = now
        deal()
    }

    var isComplete: Bool { finished }
    var accuracy: Double { attempted > 0 ? Double(correct) / Double(attempted) : 0 }
    var boardCleared: Bool { !cards.isEmpty && cards.allSatisfy { $0.matched } }
    var columns: Int { cards.count <= 6 ? 3 : 4 }

    private func pairs(for level: Int) -> Int { min(2 + level, 8) } // Lv1→3 对 … Lv6→8 对（每档牌数都在涨，不存在同难度刷分档）

    private func deal() {
        let p = pairs(for: level)
        var values = (Array(1...p) + Array(1...p))
        values.shuffle()
        cards = values.enumerated().map { Card(id: $0.offset, value: $0.element) }
        firstIndex = nil
        secondIndex = nil
        locked = false
        previewing = true
    }

    /// 预览结束，开始配对（由 View 在全亮若干秒后调用）。
    func endPreview() { previewing = false }

    /// 清完一副牌后升档发新牌（由 View 在匹配动画后延时调用）。
    func dealNext() {
        guard !finished else { return }
        boardsCleared += 1
        level = min(level + 1, levelCap)
        peakLevel = max(peakLevel, level)
        deal()
    }

    @discardableResult
    func flip(at index: Int) -> Resolution {
        guard !finished, !previewing, !locked, cards.indices.contains(index) else { return .ignored }
        guard !cards[index].matched, !cards[index].faceUp else { return .ignored }

        cards[index].faceUp = true

        if firstIndex == nil {
            firstIndex = index
            return .flippedFirst
        }

        secondIndex = index
        attempted += 1
        let first = firstIndex!
        if cards[first].value == cards[index].value {
            cards[first].matched = true
            cards[index].matched = true
            correct += 1
            combo += 1
            maxCombo = max(maxCombo, combo)
            let gain = (20 * level) * DevilCombo.multiplier(combo)
            score += gain
            lastGain = gain
            firstIndex = nil
            secondIndex = nil
            return .matched
        } else {
            combo = 0
            locked = true
            return .mismatch
        }
    }

    /// 不匹配时由 View 延时调用，翻回两张牌。
    func resolveMismatch() {
        if let a = firstIndex { cards[a].faceUp = false }
        if let b = secondIndex { cards[b].faceUp = false }
        firstIndex = nil
        secondIndex = nil
        locked = false
    }

    func finish() { finished = true }
}
