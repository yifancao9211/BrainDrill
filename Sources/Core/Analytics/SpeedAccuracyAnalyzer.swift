import Foundation

struct SATrialData {
    let rt: TimeInterval
    let correct: Bool
}

enum SABias: Equatable {
    case speed
    case accuracy
    case balanced
    case unknown
}

struct SAEvaluation: Equatable {
    let bias: SABias
    let medianRT: TimeInterval
    let accuracy: Double
    let advice: String?
}

enum SpeedAccuracyAnalyzer {
    static let minimumTrials = 10
    static let speedRTThreshold: TimeInterval = 0.250
    static let accuracyRTThreshold: TimeInterval = 0.500
    static let lowAccuracyThreshold = 0.70

    static func evaluate(trials: [SATrialData]) -> SAEvaluation {
        guard trials.count >= minimumTrials else {
            return SAEvaluation(bias: .unknown, medianRT: 0, accuracy: 0, advice: nil)
        }

        let rts = trials.map(\.rt)
        let medRT = MetricsCalculator.medianRT(rts)
        let correctCount = trials.filter(\.correct).count
        let acc = Double(correctCount) / Double(trials.count)

        let bias: SABias
        let advice: String?

        if medRT < speedRTThreshold && acc < lowAccuracyThreshold {
            bias = .speed
            advice = "你偏快但不准，建议放慢速度提高正确率"
        } else if medRT > accuracyRTThreshold && acc > 0.90 {
            bias = .accuracy
            advice = "你偏稳但偏慢，可以尝试加快速度"
        } else {
            bias = .balanced
            advice = nil
        }

        return SAEvaluation(bias: bias, medianRT: medRT, accuracy: acc, advice: advice)
    }
}
