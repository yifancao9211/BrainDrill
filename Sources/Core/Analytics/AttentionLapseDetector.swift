import Foundation

struct LapseAnalysis: Equatable {
    let lapseCount: Int
    let lapseIndices: [Int]
    let lapseRate: Double
    let medianRT: TimeInterval
    let lapseThreshold: TimeInterval
}

enum AttentionLapseDetector {
    static let lapseMultiplier = 2.5

    static func analyze(reactionTimes: [TimeInterval]) -> LapseAnalysis {
        guard !reactionTimes.isEmpty else {
            return LapseAnalysis(lapseCount: 0, lapseIndices: [], lapseRate: 0, medianRT: 0, lapseThreshold: 0)
        }

        let medRT = MetricsCalculator.medianRT(reactionTimes)
        let threshold = medRT * lapseMultiplier

        var lapseIndices: [Int] = []
        for (i, rt) in reactionTimes.enumerated() {
            if rt > threshold {
                lapseIndices.append(i)
            }
        }

        let lapseRate = Double(lapseIndices.count) / Double(reactionTimes.count)

        return LapseAnalysis(
            lapseCount: lapseIndices.count,
            lapseIndices: lapseIndices,
            lapseRate: lapseRate,
            medianRT: medRT,
            lapseThreshold: threshold
        )
    }
}
