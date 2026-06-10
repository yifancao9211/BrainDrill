import Testing
@testable import BrainDrill

struct DevilScoringTests {
    @Test
    func comboMultiplierTiers() {
        #expect(DevilCombo.multiplier(0) == 1)
        #expect(DevilCombo.multiplier(2) == 1)
        #expect(DevilCombo.multiplier(3) == 2)
        #expect(DevilCombo.multiplier(5) == 2)
        #expect(DevilCombo.multiplier(6) == 3)
        #expect(DevilCombo.multiplier(9) == 3)
        #expect(DevilCombo.multiplier(10) == 4)
        #expect(DevilCombo.multiplier(50) == 4)
    }

    @Test
    func comboTierNames() {
        #expect(DevilCombo.tier(2) == nil)
        #expect(DevilCombo.tier(3)?.name == "火热")
        #expect(DevilCombo.tier(6)?.name == "狂热")
        #expect(DevilCombo.tier(10)?.name == "魔鬼")
    }

    @Test
    func gradeSpansFromDtoS() {
        #expect(DevilGrade.evaluate(accuracy: 1.0, peakLevel: 8, maxLevel: 8) == .S)
        #expect(DevilGrade.evaluate(accuracy: 0.0, peakLevel: 1, maxLevel: 8) == .D)
        let mid = DevilGrade.evaluate(accuracy: 0.7, peakLevel: 4, maxLevel: 8)
        #expect([DevilGrade.B, .C].contains(mid))
    }

    @Test
    func calcGainUsesMultiplierAtComboTier() {
        let engine = DevilCalcEngine(startLevel: 1, totalSeconds: 90)
        func answerDue() {
            while !engine.isAnswerDue { engine.advanceWarmup() }
            engine.answer(engine.dueProblem!.answer)
        }
        answerDue() // combo 1, 倍率 1
        answerDue() // combo 2, 倍率 1
        answerDue() // combo 3：倍率 2，gain = 10 * level * 2 = 20
        #expect(engine.combo == 3)
        #expect(engine.lastGain == 20)   // 进入火热层，倍率 2×
        #expect(engine.level == 1)       // 局内 N 固定，连对不升 N
    }

    @Test
    func calcLevelStaysFixedWithinSession() {
        let engine = DevilCalcEngine(startLevel: 2, totalSeconds: 90)
        while !engine.isAnswerDue { engine.advanceWarmup() }
        for _ in 0..<8 {
            let due = engine.dueProblem!
            // 交替答对/答错，N 都不该变。
            engine.answer(Bool.random() ? due.answer : due.answer + 1)
            #expect(engine.level == 2)
            #expect(engine.peakLevel == 2)
            #expect(engine.isAnswerDue)   // 队列稳定保持 N+1，始终有应答题
        }
    }

    @Test
    func calcNextStartLevelAdjustsBetweenSessions() {
        // 样本不足不调整
        #expect(DevilCalcEngine.nextStartLevel(level: 2, accuracy: 1.0, attempted: 5) == 2)
        // 打得稳 → 下局加深一层（封顶 maxLevel）
        #expect(DevilCalcEngine.nextStartLevel(level: 2, accuracy: 0.9, attempted: 10) == 3)
        #expect(DevilCalcEngine.nextStartLevel(level: 4, accuracy: 1.0, attempted: 10) == 4)
        // 打崩了 → 退一层（保底 1）
        #expect(DevilCalcEngine.nextStartLevel(level: 2, accuracy: 0.4, attempted: 10) == 1)
        #expect(DevilCalcEngine.nextStartLevel(level: 1, accuracy: 0.0, attempted: 10) == 1)
        // 中间地带不动
        #expect(DevilCalcEngine.nextStartLevel(level: 3, accuracy: 0.7, attempted: 10) == 3)
    }
}
