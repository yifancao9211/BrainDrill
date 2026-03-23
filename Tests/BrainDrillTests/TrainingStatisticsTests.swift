import Foundation
import Testing
@testable import BrainDrill

struct TrainingStatisticsTests {
    @Test
    func computesMultiModuleStats() {
        let now = Date(timeIntervalSince1970: 2_000)
        let sessions: [SessionResult] = [
            SessionResult(module: .mainIdea, startedAt: now, endedAt: now, duration: 42, metrics: .mainIdea(MainIdeaMetrics(
                passageID: "p1",
                difficulty: 1,
                isCorrect: true,
                selectedIndex: 1,
                readingDuration: 25,
                responseDuration: 17
            ))),
            SessionResult(module: .schulte, startedAt: now, endedAt: now, duration: 29, metrics: .schulte(SchulteMetrics(difficulty: .focus4x4, mistakeCount: 1, setIndex: 0, repIndex: 0))),
            SessionResult(module: .nBack, startedAt: now, endedAt: now, duration: 180, metrics: .nBack(NBackMetrics(nLevel: 2, totalTrials: 60, hitRate: 0.8, falseAlarmRate: 0.1, dPrime: 2.3))),
            SessionResult(module: .flanker, startedAt: now, endedAt: now, duration: 120, metrics: .flanker(FlankerMetrics(totalTrials: 80, congruentRT: 0.4, incongruentRT: 0.5, conflictCost: 0.1, accuracy: 0.9, stimulusDurationMs: 200))),
        ]

        let stats = TrainingStatistics(sessions: sessions)

        #expect(stats.totalSessions == 3)
        #expect(stats.readingSessionCount == 1)
        #expect(stats.supportSessionCount == 2)
        #expect(stats.lastReadingModuleName == "主旨")
        #expect(stats.count(for: .mainIdea) == 1)
        #expect(stats.count(for: .schulte) == 1)
        #expect(stats.count(for: .nBack) == 1)
        #expect(stats.count(for: .flanker) == 0)
    }
}
