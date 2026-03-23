import Foundation
import Testing
@testable import BrainDrill

struct TrainingSchedulerTests {
    @Test func recommendsModulesWithNoHistory() {
        let recs = TrainingScheduler.recommend(sessions: [], allModules: TrainingModule.allCases)
        #expect(!recs.isEmpty)
        #expect(recs.count <= 5)
    }

    @Test func prioritizesUntrainedModules() {
        let now = Date()
        let sessions = [
            SessionResult(module: .mainIdea, startedAt: now, endedAt: now, duration: 60,
                          metrics: .mainIdea(MainIdeaMetrics(passageID: "p1", difficulty: 1, isCorrect: true, selectedIndex: 1, readingDuration: 40, responseDuration: 20))),
        ]
        let recs = TrainingScheduler.recommend(sessions: sessions, allModules: TrainingModule.allCases)
        let firstModule = recs.first?.module
        #expect(firstModule != .mainIdea)
    }

    @Test func prioritizesDecliningModules() {
        let now = Date()
        var sessions: [SessionResult] = []
        for i in 0..<5 {
            let isCorrect = i < 2
            sessions.append(SessionResult(
                module: .mainIdea,
                startedAt: now.addingTimeInterval(Double(-i) * 86400),
                endedAt: now.addingTimeInterval(Double(-i) * 86400 + 60),
                duration: 60,
                metrics: .mainIdea(MainIdeaMetrics(
                    passageID: "p\(i)",
                    difficulty: 1,
                    isCorrect: isCorrect,
                    selectedIndex: 0,
                    readingDuration: 40,
                    responseDuration: 20
                ))
            ))
        }
        for i in 0..<5 {
            sessions.append(SessionResult(
                module: .evidenceMap,
                startedAt: now.addingTimeInterval(Double(-i) * 86400),
                endedAt: now.addingTimeInterval(Double(-i) * 86400 + 90),
                duration: 90,
                metrics: .evidenceMap(EvidenceMapMetrics(
                    passageID: "e\(i)",
                    difficulty: 2,
                    totalItems: 4,
                    correctItems: 3,
                    falseSelections: 1,
                    accuracy: 0.75,
                    responseDuration: 24
                ))
            ))
        }

        let recs = TrainingScheduler.recommend(sessions: sessions, allModules: [.mainIdea, .evidenceMap])
        let mainIdeaPriority = recs.first { $0.module == .mainIdea }?.priority ?? 0
        let evidencePriority = recs.first { $0.module == .evidenceMap }?.priority ?? 0
        #expect(mainIdeaPriority >= evidencePriority)
    }

    @Test func recommendationHasReason() {
        let recs = TrainingScheduler.recommend(sessions: [], allModules: [.delayedRecall])
        #expect(recs.first?.reason != nil)
    }

    @Test func maxRecommendations() {
        let recs = TrainingScheduler.recommend(sessions: [], allModules: TrainingModule.allCases, maxCount: 3)
        #expect(recs.count <= 3)
    }
}
