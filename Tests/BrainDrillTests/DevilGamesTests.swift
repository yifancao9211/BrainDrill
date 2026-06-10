import Testing
@testable import BrainDrill

struct DevilFlipEngineTests {
    private func matchingIndex(_ e: DevilFlipEngine, of i: Int) -> Int {
        let v = e.cards[i].value
        return e.cards.indices.first { $0 != i && !e.cards[$0].matched && e.cards[$0].value == v }!
    }

    @Test
    func dealsPairedBoard() {
        let e = DevilFlipEngine(startLevel: 1)
        #expect(e.cards.count == 6) // 3 对
        let counts = Dictionary(grouping: e.cards, by: { $0.value }).mapValues(\.count)
        #expect(counts.values.allSatisfy { $0 == 2 })
    }

    /// 每一档牌数都必须严格递增——不允许出现「难度不变、得分照涨」的假档位。
    @Test func everyLevelGrowsBoard() {
        var previous = 0
        for level in 1...DevilFlipEngine.maxLevel {
            let e = DevilFlipEngine(startLevel: level)
            #expect(e.cards.count > previous, "Lv\(level) 的牌数应比上一档多")
            previous = e.cards.count
        }
        #expect(previous == 16) // 满档 8 对
    }

    @Test
    func previewBlocksFlipUntilEnded() {
        let e = DevilFlipEngine(startLevel: 1)
        #expect(e.previewing)
        #expect(e.flip(at: 0) == .ignored)   // 预览期不能翻
        e.endPreview()
        #expect(!e.previewing)
        #expect(e.flip(at: 0) == .flippedFirst)
    }

    @Test
    func matchingPairScoresAndCombos() {
        let e = DevilFlipEngine(startLevel: 1)
        e.endPreview()
        let j = matchingIndex(e, of: 0)
        #expect(e.flip(at: 0) == .flippedFirst)
        #expect(e.flip(at: j) == .matched)
        #expect(e.cards[0].matched && e.cards[j].matched)
        #expect(e.correct == 1 && e.combo == 1 && e.score > 0)
    }

    @Test
    func mismatchLocksThenResolves() {
        let e = DevilFlipEngine(startLevel: 1)
        e.endPreview()
        let av = e.cards[0].value
        let b = e.cards.indices.first { e.cards[$0].value != av }!
        #expect(e.flip(at: 0) == .flippedFirst)
        #expect(e.flip(at: b) == .mismatch)
        #expect(e.locked)
        e.resolveMismatch()
        #expect(!e.cards[0].faceUp && !e.cards[b].faceUp && !e.locked && e.combo == 0)
    }

    @Test
    func clearingBoardDealsNextAndLevelsUp() {
        let e = DevilFlipEngine(startLevel: 1)
        e.endPreview()
        while !e.boardCleared {
            let i = e.cards.firstIndex { !$0.matched && !$0.faceUp }!
            let j = matchingIndex(e, of: i)
            e.flip(at: i); e.flip(at: j)
        }
        #expect(e.boardCleared)
        e.dealNext()
        #expect(e.level == 2 && e.boardsCleared == 1 && e.cards.count == 8 && !e.boardCleared)
    }
}

struct DevilMouseEngineTests {
    @Test
    func startsInMemorizeWithTargets() {
        let m = DevilMouseEngine(startLevel: 1)
        #expect(m.phase == .memorize)
        #expect(m.targets.count == 2) // min(1+1, 9-2)
        #expect(m.gridCount == 9)
    }

    @Test
    func correctRecallScoresAndLevelsUp() {
        let m = DevilMouseEngine(startLevel: 1)
        m.beginRecall()
        #expect(m.phase == .recall)
        for t in m.targets { m.toggle(t) }
        // 选满不再自动判定，需要玩家确认提交
        #expect(m.phase == .recall)
        #expect(m.canSubmit)
        m.submitSelection()
        #expect(m.phase == .reveal)
        #expect(m.lastRoundCorrect == true)
        #expect(m.correct == 1 && m.combo == 1 && m.score > 0 && m.level == 2)
        m.nextRound()
        #expect(m.phase == .memorize)
    }

    @Test
    func wrongRecallResetsComboAndEases() {
        let m = DevilMouseEngine(startLevel: 3)
        let targetN = m.targets.count
        m.beginRecall()
        let nonTargets = (0..<m.gridCount).filter { !m.targets.contains($0) }
        for i in nonTargets.prefix(targetN) { m.toggle(i) }
        m.submitSelection()
        #expect(m.phase == .reveal)
        #expect(m.lastRoundCorrect == false)
        #expect(m.combo == 0 && m.level == 2)
    }

    @Test
    func lastPickCanBeRevisedBeforeSubmit() {
        let m = DevilMouseEngine(startLevel: 1)
        m.beginRecall()
        let nonTarget = (0..<m.gridCount).first { !m.targets.contains($0) }!
        let targets = Array(m.targets)
        m.toggle(targets[0])
        m.toggle(nonTarget)          // 手滑点错最后一格
        #expect(m.canSubmit)
        m.toggle(nonTarget)          // 反悔：取消误选
        #expect(!m.canSubmit)
        m.toggle(targets[1])         // 改成正确的
        m.submitSelection()
        #expect(m.lastRoundCorrect == true)
    }
}
