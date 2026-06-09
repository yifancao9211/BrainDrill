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
        #expect(m.phase == .reveal)
        #expect(m.lastRoundCorrect == false)
        #expect(m.combo == 0 && m.level == 2)
    }
}
