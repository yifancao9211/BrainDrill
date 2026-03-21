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
            SessionResult(module: .choiceRT, startedAt: now, endedAt: now, duration: 60,
                          metrics: .choiceRT(ChoiceRTMetrics(totalTrials: 30, medianRT: 0.35, rtStandardDeviation: 0.04, accuracy: 0.90, postErrorSlowing: 0.02, anticipationCount: 0, choiceCount: 2))),
        ]
        let recs = TrainingScheduler.recommend(sessions: sessions, allModules: TrainingModule.allCases)
        let firstModule = recs.first?.module
        #expect(firstModule != .choiceRT)
    }

    @Test func prioritizesDecliningModules() {
        let now = Date()
        var sessions: [SessionResult] = []
        for i in 0..<5 {
            let rt = 0.30 + Double(i) * 0.05
            sessions.append(SessionResult(
                module: .choiceRT,
                startedAt: now.addingTimeInterval(Double(-i) * 86400),
                endedAt: now.addingTimeInterval(Double(-i) * 86400 + 60),
                duration: 60,
                metrics: .choiceRT(ChoiceRTMetrics(totalTrials: 30, medianRT: rt, rtStandardDeviation: 0.04, accuracy: 0.90, postErrorSlowing: 0.02, anticipationCount: 0, choiceCount: 2))
            ))
        }
        for i in 0..<5 {
            sessions.append(SessionResult(
                module: .goNoGo,
                startedAt: now.addingTimeInterval(Double(-i) * 86400),
                endedAt: now.addingTimeInterval(Double(-i) * 86400 + 90),
                duration: 90,
                metrics: .goNoGo(GoNoGoMetrics(totalTrials: 60, goRT: 0.35, goAccuracy: 0.95, noGoAccuracy: 0.85, dPrime: 2.5))
            ))
        }

        let recs = TrainingScheduler.recommend(sessions: sessions, allModules: [.choiceRT, .goNoGo])
        let choiceRTPriority = recs.first { $0.module == .choiceRT }?.priority ?? 0
        let goNoGoPriority = recs.first { $0.module == .goNoGo }?.priority ?? 0
        #expect(choiceRTPriority >= goNoGoPriority)
    }

    @Test func recommendationHasReason() {
        let recs = TrainingScheduler.recommend(sessions: [], allModules: [.digitSpan])
        #expect(recs.first?.reason != nil)
    }

    @Test func maxRecommendations() {
        let recs = TrainingScheduler.recommend(sessions: [], allModules: TrainingModule.allCases, maxCount: 3)
        #expect(recs.count <= 3)
    }
}
