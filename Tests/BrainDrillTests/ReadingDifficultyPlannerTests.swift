import Foundation
import Testing
@testable import BrainDrill

struct ReadingDifficultyPlannerTests {
    @Test
    func startsAtDifficultyOneWithoutHistory() {
        #expect(ReadingDifficultyPlanner.nextDifficulty(for: .mainIdea, sessions: []) == 1)
        #expect(ReadingDifficultyPlanner.nextPassage(for: .mainIdea, sessions: []).difficulty == 1)
    }

    @Test
    func promotesMainIdeaAfterStrongPerformance() {
        let now = Date(timeIntervalSince1970: 10_000)
        let sessions = [
            SessionResult(
                module: .mainIdea,
                startedAt: now,
                endedAt: now.addingTimeInterval(80),
                duration: 80,
                metrics: .mainIdea(MainIdeaMetrics(
                    passageID: "microplastic-river",
                    difficulty: 1,
                    isCorrect: true,
                    selectedIndex: 1,
                    generatedSummary: "城市源头微塑料经河流进入食物链，源头控制更关键。",
                    matchedKeywordCount: 5,
                    totalKeywordCount: 5,
                    readingDuration: 50,
                    responseDuration: 30
                ))
            ),
            SessionResult(
                module: .mainIdea,
                startedAt: now.addingTimeInterval(-200),
                endedAt: now.addingTimeInterval(-120),
                duration: 80,
                metrics: .mainIdea(MainIdeaMetrics(
                    passageID: "microplastic-river",
                    difficulty: 1,
                    isCorrect: true,
                    selectedIndex: 1,
                    generatedSummary: "城市源头决定河流微塑料输入，控制源头最关键。",
                    matchedKeywordCount: 4,
                    totalKeywordCount: 5,
                    readingDuration: 48,
                    responseDuration: 32
                ))
            ),
        ]

        #expect(ReadingDifficultyPlanner.nextDifficulty(for: .mainIdea, sessions: sessions) == 2)
        #expect(ReadingDifficultyPlanner.nextPassage(for: .mainIdea, sessions: sessions).difficulty == 2)
    }

    @Test
    func lowersDelayedRecallAfterWeakPerformance() {
        let now = Date(timeIntervalSince1970: 20_000)
        let sessions = [
            SessionResult(
                module: .delayedRecall,
                startedAt: now,
                endedAt: now.addingTimeInterval(160),
                duration: 160,
                metrics: .delayedRecall(DelayedRecallMetrics(
                    passageID: "battery-sodium",
                    difficulty: 3,
                    delaySeconds: 75,
                    totalTargets: 3,
                    recalledTargets: 1,
                    intrusionCount: 2,
                    accuracy: 0.33,
                    freeRecallText: "记得钠电便宜。",
                    freeRecallKeywordHits: 1,
                    freeRecallKeywordTotal: 5,
                    distractorQuestionCount: 4,
                    distractorCorrectCount: 2,
                    responseDuration: 40
                ))
            ),
        ]

        #expect(ReadingDifficultyPlanner.nextDifficulty(for: .delayedRecall, sessions: sessions) == 2)
        #expect(ReadingDifficultyPlanner.nextPassage(for: .delayedRecall, sessions: sessions).difficulty == 2)
    }
}
