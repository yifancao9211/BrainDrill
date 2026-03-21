import Foundation
import Testing
@testable import BrainDrill

struct CognitiveProfileTests {
    @Test func computesAllFiveDimensions() {
        let profile = CognitiveProfile.compute(from: sampleSessions())
        #expect(profile.dimensions.count == 5)
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
            module: .choiceRT, startedAt: now, endedAt: now, duration: 60,
            metrics: .choiceRT(ChoiceRTMetrics(totalTrials: 30, medianRT: 0.250, rtStandardDeviation: 0.03, accuracy: 0.95, postErrorSlowing: 0.01, anticipationCount: 0, choiceCount: 2))
        )
        let bad = SessionResult(
            module: .choiceRT, startedAt: now, endedAt: now, duration: 60,
            metrics: .choiceRT(ChoiceRTMetrics(totalTrials: 30, medianRT: 0.600, rtStandardDeviation: 0.15, accuracy: 0.60, postErrorSlowing: 0.05, anticipationCount: 5, choiceCount: 2))
        )

        let goodProfile = CognitiveProfile.compute(from: [good])
        let badProfile = CognitiveProfile.compute(from: [bad])

        let goodRT = goodProfile.dimensions.first { $0.id == "reactionSpeed" }!.score
        let badRT = badProfile.dimensions.first { $0.id == "reactionSpeed" }!.score
        #expect(goodRT > badRT)
    }

    @Test func dimensionIdsAreCorrect() {
        let profile = CognitiveProfile.compute(from: [])
        let ids = Set(profile.dimensions.map(\.id))
        #expect(ids == ["memoryCapacity", "reactionSpeed", "inhibitionControl", "visualSearch", "visualWorkingMemory"])
    }

    private func sampleSessions() -> [SessionResult] {
        let now = Date()
        return [
            SessionResult(module: .digitSpan, startedAt: now, endedAt: now, duration: 120,
                          metrics: .digitSpan(DigitSpanMetrics(maxSpanForward: 7, maxSpanBackward: 5, totalTrials: 10, correctTrials: 8, accuracy: 0.8, positionErrors: 3))),
            SessionResult(module: .choiceRT, startedAt: now, endedAt: now, duration: 60,
                          metrics: .choiceRT(ChoiceRTMetrics(totalTrials: 30, medianRT: 0.350, rtStandardDeviation: 0.05, accuracy: 0.90, postErrorSlowing: 0.02, anticipationCount: 1, choiceCount: 2))),
            SessionResult(module: .goNoGo, startedAt: now, endedAt: now, duration: 90,
                          metrics: .goNoGo(GoNoGoMetrics(totalTrials: 60, goRT: 0.35, goAccuracy: 0.95, noGoAccuracy: 0.85, dPrime: 2.5))),
            SessionResult(module: .visualSearch, startedAt: now, endedAt: now, duration: 120,
                          metrics: .visualSearch(VisualSearchMetrics(totalTrials: 30, accuracy: 0.90, searchSlope: 0.025, presentRT: 0.8, absentRT: 1.2, setSizeRTs: [8: 0.5, 16: 0.7, 24: 0.9], errorRate: 0.10))),
            SessionResult(module: .changeDetection, startedAt: now, endedAt: now, duration: 80,
                          metrics: .changeDetection(ChangeDetectionMetrics(totalTrials: 20, accuracy: 0.85, dPrime: 2.0, hitRate: 0.90, falseAlarmRate: 0.15, maxSetSize: 5, averageRT: 0.6))),
        ]
    }
}
