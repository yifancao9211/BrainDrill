import Foundation
import Testing
@testable import BrainDrill

struct TrainingStatisticsTests {
    @Test
    func computesBestAverageAndTrend() {
        let now = Date(timeIntervalSince1970: 2_000)
        let results = [
            SchulteSessionResult(startedAt: now, endedAt: now, duration: 29, difficulty: .focus4x4, mistakeCount: 1),
            SchulteSessionResult(startedAt: now, endedAt: now, duration: 33, difficulty: .focus4x4, mistakeCount: 0),
            SchulteSessionResult(startedAt: now, endedAt: now, duration: 31, difficulty: .focus4x4, mistakeCount: 2),
            SchulteSessionResult(startedAt: now, endedAt: now, duration: 37, difficulty: .easy3x3, mistakeCount: 1)
        ]

        let stats = TrainingStatistics(results: results)

        #expect(stats.totalSessions == 4)
        #expect(stats.bestTime == 29)
        #expect(stats.recentAverage == 32.5)
        #expect(stats.mostPlayedDifficulty == .focus4x4)
        #expect(stats.recentTrend.count == 4)
        #expect(abs((stats.recentImprovement ?? 0) + 4.666666666666664) < 0.0001)
    }
}
