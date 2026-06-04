import Foundation
import Testing
@testable import BrainDrill

struct CognitiveProfileTests {
    @Test func computesAllDimensions() {
        let profile = CognitiveProfile.compute(from: sampleSessions())
        #expect(profile.dimensions.count == 3)
    }

    @Test func scoresAreNormalized0to100() {
        let profile = CognitiveProfile.compute(from: sampleSessions())
        for dim in profile.dimensions {
            #expect(dim.score >= 0 && dim.score <= 100)
        }
    }

    @Test func emptySessionsReturnZeroScores() {
        let profile = CognitiveProfile.compute(from: [])
        for dim in profile.dimensions {
            #expect(dim.score == 0)
        }
    }

    @Test func betterPerformanceGivesHigherScore() {
        let now = Date()
        let good = SessionResult(
            module: .digitSpan, startedAt: now, endedAt: now, duration: 60,
            metrics: .digitSpan(DigitSpanMetrics(maxSpanForward: 9, maxSpanBackward: 8, totalTrials: 10, correctTrials: 10, accuracy: 1.0, positionErrors: 0))
        )
        let bad = SessionResult(
            module: .digitSpan, startedAt: now, endedAt: now, duration: 60,
            metrics: .digitSpan(DigitSpanMetrics(maxSpanForward: 3, maxSpanBackward: 2, totalTrials: 10, correctTrials: 4, accuracy: 0.4, positionErrors: 6))
        )

        let goodProfile = CognitiveProfile.compute(from: [good])
        let badProfile = CognitiveProfile.compute(from: [bad])

        let goodMemory = goodProfile.dimensions.first { $0.id == "memoryCapacity" }!.score
        let badMemory = badProfile.dimensions.first { $0.id == "memoryCapacity" }!.score
        #expect(goodMemory > badMemory)
    }

    @Test func dimensionIdsAreCorrect() {
        let profile = CognitiveProfile.compute(from: [])
        let ids = Set(profile.dimensions.map(\.id))
        #expect(ids == ["memoryCapacity", "visualWorkingMemory", "logicalReasoning"])
    }

    private func sampleSessions() -> [SessionResult] {
        let now = Date()
        return [
            SessionResult(module: .digitSpan, startedAt: now, endedAt: now, duration: 120,
                          metrics: .digitSpan(DigitSpanMetrics(maxSpanForward: 7, maxSpanBackward: 5, totalTrials: 10, correctTrials: 8, accuracy: 0.8, positionErrors: 3))),
            SessionResult(module: .changeDetection, startedAt: now, endedAt: now, duration: 80,
                          metrics: .changeDetection(ChangeDetectionMetrics(totalTrials: 20, accuracy: 0.85, dPrime: 2.0, hitRate: 0.90, falseAlarmRate: 0.15, maxSetSize: 5, averageRT: 0.6))),
        ]
    }
}
