import Foundation

struct FatigueEvaluation: Equatable {
    let isFatigued: Bool
    let rtTrend: Double
    let accuracyTrend: Double
    let message: String?
}

enum FatigueDetector {
    static let minimumSamples = 5
    static let rtTrendThreshold = 0.015
    static let accuracyTrendThreshold = -0.05

    static func evaluate(recentRTs: [TimeInterval], recentAccuracies: [Double]) -> FatigueEvaluation {
        guard recentRTs.count >= minimumSamples else {
            return FatigueEvaluation(isFatigued: false, rtTrend: 0, accuracyTrend: 0, message: nil)
        }

        let rtSlope = linearTrend(recentRTs)
        let accSlope = recentAccuracies.count >= minimumSamples ? linearTrend(recentAccuracies) : 0

        let rtFatigued = rtSlope > rtTrendThreshold
        let accFatigued = accSlope < accuracyTrendThreshold

        let fatigued = rtFatigued || accFatigued

        var message: String?
        if fatigued {
            if rtFatigued && accFatigued {
                message = "反应变慢且正确率下降，建议休息"
            } else if rtFatigued {
                message = "反应速度持续下降，建议休息"
            } else {
                message = "正确率持续下降，建议休息"
            }
        }

        return FatigueEvaluation(
            isFatigued: fatigued,
            rtTrend: rtSlope,
            accuracyTrend: accSlope,
            message: message
        )
    }

    static func linearTrend(_ values: [Double]) -> Double {
        let n = Double(values.count)
        guard n >= 2 else { return 0 }

        var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0
        for (i, y) in values.enumerated() {
            let x = Double(i)
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }

        let denom = n * sumX2 - sumX * sumX
        guard denom != 0 else { return 0 }
        return (n * sumXY - sumX * sumY) / denom
    }
}
