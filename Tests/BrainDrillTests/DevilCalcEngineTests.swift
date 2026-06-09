import Testing
@testable import BrainDrill

struct DevilCalcEngineTests {
    /// 热身补题直到出现应答题，然后答对它。
    private func answerCorrectly(_ e: DevilCalcEngine) {
        while !e.isAnswerDue { e.advanceWarmup() }
        e.answer(e.dueProblem!.answer)
    }

    private func answerWrong(_ e: DevilCalcEngine) {
        while !e.isAnswerDue { e.advanceWarmup() }
        e.answer(e.dueProblem!.answer + 1000)   // 必错
    }

    @Test
    func maxLevelIsFour() {
        #expect(DevilCalcEngine.maxLevel == 4)
    }

    @Test
    func everyOptionSetHasFourIncludingAnswer() {
        for _ in 0..<30 {
            let p = DevilCalcEngine.makeProblem()
            let opts = DevilCalcEngine.makeOptions(answer: p.answer)
            #expect(opts.count == 4)
            #expect(Set(opts).count == 4)
            #expect(opts.contains(p.answer))
        }
    }

    @Test
    func warmupCreatesAnswerDueAfterNProblems() {
        let e = DevilCalcEngine(startLevel: 2)   // N=2：初始 1 题，需再热身到 count>2
        #expect(!e.isAnswerDue)
        e.advanceWarmup()
        #expect(!e.isAnswerDue)                  // count=2，仍不足
        e.advanceWarmup()
        #expect(e.isAnswerDue)                   // count=3 > 2
        #expect(e.options.contains(e.dueProblem!.answer))
    }

    @Test
    func correctAnswerScoresAndCombos() {
        let e = DevilCalcEngine(startLevel: 1)
        answerCorrectly(e)
        #expect(e.correct == 1)
        #expect(e.attempted == 1)
        #expect(e.combo == 1)
        #expect(e.score > 0)
        #expect(e.lastAnsweredCorrectly == true)
    }

    @Test
    func threeInARowRaisesN() {
        let e = DevilCalcEngine(startLevel: 1)
        answerCorrectly(e); answerCorrectly(e); answerCorrectly(e)
        #expect(e.level == 2)        // N 从 1 升到 2
        #expect(e.maxCombo == 3)
    }

    @Test
    func wrongAnswerLowersN() {
        let e = DevilCalcEngine(startLevel: 3)
        answerWrong(e)
        #expect(e.combo == 0)
        #expect(e.level == 2)        // N 从 3 降到 2
        #expect(e.lastAnsweredCorrectly == false)
    }

    @Test
    func finishMarksComplete() {
        let e = DevilCalcEngine(startLevel: 1)
        #expect(!e.isComplete)
        e.finish()
        #expect(e.isComplete)
    }
}
