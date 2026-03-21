import Foundation
import Testing
@testable import BrainDrill

struct AdaptiveDifficultyTests {
    private let now = Date(timeIntervalSince1970: 10_000)

    private func makeResult(duration: TimeInterval, difficulty: SchulteDifficulty, mistakes: Int = 0) -> SchulteSessionResult {
        SchulteSessionResult(startedAt: now, endedAt: now.addingTimeInterval(duration), duration: duration, difficulty: difficulty, mistakeCount: mistakes)
    }

    @Test func scorePerfectAtBase() {
        let r = makeResult(duration: 10, difficulty: .easy3x3)
        #expect(abs(AdaptiveDifficulty.sessionScore(result: r) - 1.0) < 0.001)
    }

    @Test func scoreFasterIsAboveOne() {
        let r = makeResult(duration: 5, difficulty: .easy3x3)
        #expect(AdaptiveDifficulty.sessionScore(result: r) > 1.0)
    }

    @Test func staysWithInsufficientData() {
        let history = [makeResult(duration: 8, difficulty: .easy3x3)]
        let eval = AdaptiveDifficulty.evaluate(currentDifficulty: .easy3x3, history: history)
        #expect(eval.recommendation == .stay)
    }

    @Test func promotesAfterConsistentFast() {
        let history = (0..<5).map { _ in makeResult(duration: 7, difficulty: .easy3x3) }
        let eval = AdaptiveDifficulty.evaluate(currentDifficulty: .easy3x3, history: history)
        #expect(eval.recommendation == .promote(to: .focus4x4))
    }

    @Test func doesNotPromoteFromHighest() {
        let history = (0..<5).map { _ in makeResult(duration: 100, difficulty: .legend9x9) }
        let eval = AdaptiveDifficulty.evaluate(currentDifficulty: .legend9x9, history: history)
        #expect(eval.recommendation == .stay)
    }

    @Test func demotesAfterPoor() {
        let history = (0..<5).map { _ in makeResult(duration: 80, difficulty: .focus4x4, mistakes: 5) }
        let eval = AdaptiveDifficulty.evaluate(currentDifficulty: .focus4x4, history: history)
        #expect(eval.recommendation == .demote(to: .easy3x3))
    }

    @Test func fullDifficultyChain() {
        #expect(SchulteDifficulty.easy3x3.harder == .focus4x4)
        #expect(SchulteDifficulty.focus4x4.harder == .challenge5x5)
        #expect(SchulteDifficulty.challenge5x5.harder == .expert6x6)
        #expect(SchulteDifficulty.expert6x6.harder == .master7x7)
        #expect(SchulteDifficulty.master7x7.harder == .elite8x8)
        #expect(SchulteDifficulty.elite8x8.harder == .legend9x9)
        #expect(SchulteDifficulty.legend9x9.harder == nil)
        #expect(SchulteDifficulty.legend9x9.easier == .elite8x8)
        #expect(SchulteDifficulty.easy3x3.easier == nil)
    }

    @Test func baseDurationsAreScientific() {
        #expect(AdaptiveDifficulty.baseDuration(for: .easy3x3) == 10)
        #expect(AdaptiveDifficulty.baseDuration(for: .focus4x4) == 25)
        #expect(AdaptiveDifficulty.baseDuration(for: .challenge5x5) == 40)
        #expect(AdaptiveDifficulty.baseDuration(for: .expert6x6) == 60)
        #expect(AdaptiveDifficulty.baseDuration(for: .master7x7) == 85)
        #expect(AdaptiveDifficulty.baseDuration(for: .elite8x8) == 120)
        #expect(AdaptiveDifficulty.baseDuration(for: .legend9x9) == 160)
    }
}
