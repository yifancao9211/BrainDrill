import Foundation
import Observation

/// 魔鬼抓鼠（静态记忆版）：老鼠藏在网格的若干格子里，短暂展示后盖上，凭记忆点出老鼠藏过的格子。
/// 全部点对即升档（藏身格更多/棋盘更大），点错降档。
@Observable
final class DevilMouseEngine: DevilGameEngine {
    enum Phase: Equatable { case memorize, recall, reveal }

    let totalSeconds: Int
    let startedAt: Date
    static let maxLevel = 6
    let levelCap: Int

    private(set) var level: Int
    private(set) var peakLevel: Int
    private(set) var gridCount: Int
    private(set) var targets: Set<Int> = []
    private(set) var selected: Set<Int> = []
    private(set) var phase: Phase = .memorize
    private(set) var lastRoundCorrect: Bool?

    private(set) var score: Int = 0
    private(set) var combo: Int = 0
    private(set) var maxCombo: Int = 0
    private(set) var attempted: Int = 0
    private(set) var correct: Int = 0
    private(set) var lastGain: Int = 0
    private(set) var finished: Bool = false

    init(startLevel: Int, totalSeconds: Int = 90, levelCap: Int = .max, now: Date = Date()) {
        let cap = min(max(levelCap, 1), Self.maxLevel)
        self.levelCap = cap
        let lvl = min(max(startLevel, 1), cap)
        self.level = lvl
        self.peakLevel = lvl
        self.totalSeconds = totalSeconds
        self.startedAt = now
        self.gridCount = Self.gridCount(for: lvl)
        newRound()
    }

    var isComplete: Bool { finished }
    var accuracy: Double { attempted > 0 ? Double(correct) / Double(attempted) : 0 }
    var columns: Int { gridCount >= 16 ? 4 : 3 }
    var targetCount: Int { targets.count }

    private static func gridCount(for level: Int) -> Int { level >= 4 ? 16 : 9 }
    private func targetCount(for level: Int) -> Int { min(1 + level, gridCount - 2) }

    func newRound() {
        gridCount = Self.gridCount(for: level)
        let count = targetCount(for: level)
        var chosen: Set<Int> = []
        var guard0 = 0
        while chosen.count < count && guard0 < 200 {
            guard0 += 1
            chosen.insert(Int.random(in: 0..<gridCount))
        }
        targets = chosen
        selected = []
        lastRoundCorrect = nil
        phase = .memorize
    }

    /// 记忆期结束，进入回忆期。
    func beginRecall() {
        guard phase == .memorize else { return }
        phase = .recall
    }

    /// 回忆期点选/取消点选；选满后不自动判定，留给玩家检查与反悔的机会。
    func toggle(_ index: Int) {
        guard phase == .recall, !finished, (0..<gridCount).contains(index) else { return }
        if selected.contains(index) {
            selected.remove(index)
        } else if selected.count < targets.count {
            selected.insert(index)
        }
    }

    /// 是否已选满、可以提交。
    var canSubmit: Bool { phase == .recall && !finished && selected.count == targets.count }

    /// 玩家确认提交本回合答案。
    func submitSelection() {
        guard canSubmit else { return }
        submit()
    }

    private func submit() {
        attempted += 1
        let ok = selected == targets
        lastRoundCorrect = ok
        phase = .reveal
        if ok {
            correct += 1
            combo += 1
            maxCombo = max(maxCombo, combo)
            let gain = (15 * targets.count) * DevilCombo.multiplier(combo)
            score += gain
            lastGain = gain
            level = min(level + 1, levelCap)
        } else {
            combo = 0
            level = max(1, level - 1)
        }
        peakLevel = max(peakLevel, level)
    }

    func nextRound() {
        guard !finished else { return }
        newRound()
    }

    func finish() { finished = true }
}
