import Foundation

enum WarmupDetector {
    static let minimumTrials = 5
    static let windowSize = 3
    static let dropThreshold = 0.15

    static func detectWarmupCount(reactionTimes: [TimeInterval]) -> Int {
        guard reactionTimes.count >= minimumTrials else { return 0 }

        let stableMedian = MetricsCalculator.medianRT(Array(reactionTimes.suffix(reactionTimes.count / 2)))
        guard stableMedian > 0 else { return 0 }

        var warmupEnd = 0
        for i in 0..<min(reactionTimes.count / 2, 8) {
            let excess = (reactionTimes[i] - stableMedian) / stableMedian
            if excess > dropThreshold {
                warmupEnd = i + 1
            }
        }

        return warmupEnd
    }
}
