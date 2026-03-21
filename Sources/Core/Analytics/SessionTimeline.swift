import Foundation

struct TimelinePoint: Identifiable, Equatable {
    let id: Int
    let trialIndex: Int
    let reactionTime: TimeInterval?
    let correct: Bool
    let isLapse: Bool
    let isPostError: Bool
    let isWarmup: Bool
}

struct SessionTimelineData: Equatable {
    let points: [TimelinePoint]
    let medianRT: TimeInterval
    let lapseThreshold: TimeInterval
    let warmupCount: Int
    let lapseCount: Int
    let postErrorSlowing: TimeInterval
}

enum SessionTimelineBuilder {
    static func build(from results: [(rt: TimeInterval?, correct: Bool)]) -> SessionTimelineData {
        let rts = results.compactMap(\.rt)
        let medRT = MetricsCalculator.medianRT(rts)
        let lapseThreshold = medRT * AttentionLapseDetector.lapseMultiplier
        let warmupCount = WarmupDetector.detectWarmupCount(reactionTimes: rts)

        let pairs = results.map { (correct: $0.correct, rt: $0.rt) }
        let pes = MetricsCalculator.postErrorSlowing(results: pairs)

        var lapseCount = 0
        let points = results.enumerated().map { i, r -> TimelinePoint in
            let isLapse = (r.rt ?? 0) > lapseThreshold && r.rt != nil
            if isLapse { lapseCount += 1 }
            let isPostError = i > 0 && !results[i - 1].correct
            let isWarmup = i < warmupCount

            return TimelinePoint(
                id: i,
                trialIndex: i,
                reactionTime: r.rt,
                correct: r.correct,
                isLapse: isLapse,
                isPostError: isPostError,
                isWarmup: isWarmup
            )
        }

        return SessionTimelineData(
            points: points,
            medianRT: medRT,
            lapseThreshold: lapseThreshold,
            warmupCount: warmupCount,
            lapseCount: lapseCount,
            postErrorSlowing: pes
        )
    }
}
