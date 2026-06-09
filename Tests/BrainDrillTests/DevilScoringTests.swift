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
        answerDue() // combo 3：倍率 2，gain = 10 * level(此刻=1) * 2 = 20，之后才升档
        #expect(engine.combo == 3)
        #expect(engine.lastGain == 20)   // 进入火热层，倍率 2×
        #expect(engine.level == 2)        // 三连后升 N
    }
}
