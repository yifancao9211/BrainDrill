import Foundation
import Testing
@testable import BrainDrill

struct TrainingStatisticsTests {
    @Test
    func computesMultiModuleStats() {
        let now = Date(timeIntervalSince1970: 2_000)
        let sessions: [SessionResult] = [
            SessionResult(module: .schulte, startedAt: now, endedAt: now, duration: 29, metrics: .schulte(SchulteMetrics(difficulty: .focus4x4, mistakeCount: 1, setIndex: 0, repIndex: 0))),
            SessionResult(module: .schulte, startedAt: now, endedAt: now, duration: 33, metrics: .schulte(SchulteMetrics(difficulty: .focus4x4, mistakeCount: 0, setIndex: 0, repIndex: 1))),
            SessionResult(module: .flanker, startedAt: now, endedAt: now, duration: 120, metrics: .flanker(FlankerMetrics(totalTrials: 80, congruentRT: 0.4, incongruentRT: 0.5, conflictCost: 0.1, accuracy: 0.9, stimulusDurationMs: 200))),
            SessionResult(module: .nBack, startedAt: now, endedAt: now, duration: 180, metrics: .nBack(NBackMetrics(nLevel: 2, totalTrials: 60, hitRate: 0.8, falseAlarmRate: 0.1, dPrime: 2.3))),
        ]

        let stats = TrainingStatistics(sessions: sessions)

        #expect(stats.totalSessions == 4)
        #expect(stats.schulteCount == 2)
        #expect(stats.flankerCount == 1)
        #expect(stats.nBackCount == 1)
        #expect(stats.bestSchulteTime == 29)
        #expect(stats.bestFlankerConflictCost == 0.1)
        #expect(stats.bestNBackLevel == 2)
    }
}
