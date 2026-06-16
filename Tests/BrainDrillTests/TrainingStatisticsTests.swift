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
            SessionResult(module: .digitSpan, startedAt: now, endedAt: now, duration: 120, metrics: .digitSpan(DigitSpanMetrics(maxSpanForward: 7, maxSpanBackward: 5, thresholdSpan: 0, reversalCount: 0, totalTrials: 10, correctTrials: 8, accuracy: 0.8, positionErrors: 2))),
        ]

        let stats = TrainingStatistics(sessions: sessions)

        #expect(stats.totalSessions == 4)
        #expect(stats.readingSessionCount == 1)
        #expect(stats.supportSessionCount == 3)
        #expect(stats.lastReadingModuleName == "主旨")
        #expect(stats.count(for: .mainIdea) == 1)
        #expect(stats.count(for: .schulte) == 1)
        #expect(stats.count(for: .nBack) == 1)
        #expect(stats.count(for: .digitSpan) == 1)
    }
}
