import Foundation

enum MetricsCalculator {
    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let count = sorted.count
        if count == 0 { return 0 }
        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
        }
        return sorted[count / 2]
    }

    static func medianRT(_ reactionTimes: [TimeInterval]) -> TimeInterval {
        median(reactionTimes)
    }

    static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count - 1)
        return sqrt(variance)
    }

    static func coefficientOfVariation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        guard mean > 0 else { return 0 }
        return standardDeviation(values) / mean
    }

    /// Post-error slowing: average RT on trials following an error minus average RT on trials following a correct response
    static func postErrorSlowing(results: [(correct: Bool, rt: TimeInterval?)]) -> TimeInterval {
        var postErrorRTs: [TimeInterval] = []
        var postCorrectRTs: [TimeInterval] = []

        for i in 1..<results.count {
            guard let rt = results[i].rt else { continue }
            if !results[i - 1].correct {
                postErrorRTs.append(rt)
            } else {
                postCorrectRTs.append(rt)
            }
        }

        guard !postErrorRTs.isEmpty, !postCorrectRTs.isEmpty else { return 0 }
        let avgPostError = postErrorRTs.reduce(0, +) / Double(postErrorRTs.count)
        let avgPostCorrect = postCorrectRTs.reduce(0, +) / Double(postCorrectRTs.count)
        return avgPostError - avgPostCorrect
    }

    static func zScore(_ p: Double) -> Double {
        let clamped = min(max(p, 0.0001), 0.9999)
        let t = sqrt(-2.0 * log(clamped < 0.5 ? clamped : 1.0 - clamped))
        let c0 = 2.515517, c1 = 0.802853, c2 = 0.010328
        let d1 = 1.432788, d2 = 0.189269, d3 = 0.001308
        let z = t - (c0 + c1 * t + c2 * t * t) / (1.0 + d1 * t + d2 * t * t + d3 * t * t * t)
        return clamped < 0.5 ? -z : z
    }

    static func dPrime(hitRate: Double, falseAlarmRate: Double) -> Double {
        let hr = min(max(hitRate, 0.01), 0.99)
        let fa = min(max(falseAlarmRate, 0.01), 0.99)
        return zScore(hr) - zScore(fa)
    }

    static let anticipationThreshold: TimeInterval = 0.150

    static func filterAnticipations(_ reactionTimes: [TimeInterval]) -> [TimeInterval] {
        reactionTimes.filter { $0 >= anticipationThreshold }
    }

    /// Linear regression slope: how RT increases per additional set-size item
    static func searchSlope(setSizeRTs: [(setSize: Int, rt: TimeInterval)]) -> TimeInterval {
        guard setSizeRTs.count >= 2 else { return 0 }
        let n = Double(setSizeRTs.count)
        let xs = setSizeRTs.map { Double($0.setSize) }
        let ys = setSizeRTs.map { $0.rt }
        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
        let sumX2 = xs.reduce(0) { $0 + $1 * $1 }
        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return 0 }
        return (n * sumXY - sumX * sumY) / denominator
    }
}
