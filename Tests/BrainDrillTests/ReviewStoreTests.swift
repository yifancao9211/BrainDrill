import Testing
import Foundation
@testable import BrainDrill

@Suite(.serialized)
struct ReviewStoreTests {
    private func reset() { UserDefaults.standard.removeObject(forKey: "qbank_review_v1") }

    @Test
    func wrongAnswerEntersReviewDueNow() {
        reset()
        ReviewStore.record([(id: "q1", correct: false)])
        #expect(ReviewStore.dueIDs().contains("q1"))
        reset()
    }

    @Test
    func correctReviewPushesDueOut() {
        reset()
        ReviewStore.record([(id: "q2", correct: false)])   // 入错题本，立即到期
        ReviewStore.record([(id: "q2", correct: true)])     // 复习答对 → 推到一天后
        #expect(!ReviewStore.dueIDs().contains("q2"))
        #expect(ReviewStore.load()["q2"] != nil)
        reset()
    }

    @Test
    func correctNotInReviewIsIgnored() {
        reset()
        ReviewStore.record([(id: "q3", correct: true)])
        #expect(ReviewStore.load()["q3"] == nil)
        reset()
    }

    @Test
    func graduatesAfterRepeatedCorrect() {
        reset()
        ReviewStore.record([(id: "q4", correct: false)])
        for _ in 0..<12 {
            if ReviewStore.load()["q4"] == nil { break }
            ReviewStore.record([(id: "q4", correct: true)])
        }
        #expect(ReviewStore.load()["q4"] == nil)   // 间隔达标后毕业移除
        reset()
    }
}
