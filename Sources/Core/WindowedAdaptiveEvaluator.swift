import Foundation

/// Generic windowed adaptive evaluator that applies sliding-window + stability (CV) analysis
/// to any training module's performance scores. This replaces ad-hoc per-module logic.
enum WindowedAdaptiveEvaluator {
    enum Recommendation: Equatable {
        case promote
        case stay
        case demote
    }

    struct Config {
        let windowSize: Int
        let promoteThreshold: Double
        let demoteThreshold: Double
        let maxStabilityCV: Double

        static let schulte = Config(
            windowSize: 5,
            promoteThreshold: 1.05,
            demoteThreshold: 0.65,
            maxStabilityCV: 0.15
        )

        static let reading = Config(
            windowSize: 5,
            promoteThreshold: 0.82,
            demoteThreshold: 0.55,
            maxStabilityCV: 0.20
        )

        static let general = Config(
            windowSize: 5,
            promoteThreshold: 0.80,
            demoteThreshold: 0.50,
            maxStabilityCV: 0.20
        )
    }

    static func evaluate(
        recentScores: [Double],
        config: Config
    ) -> Recommendation {
        guard recentScores.count >= config.windowSize else {
            return .stay
        }

        let window = Array(recentScores.suffix(config.windowSize))
        let median = Self.median(window)
        let cv = Self.coefficientOfVariation(window)

        let isStable = cv < config.maxStabilityCV

        if median >= config.promoteThreshold && isStable {
            return .promote
        }
        if median <= config.demoteThreshold {
            return .demote
        }
        return .stay
    }

    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let count = sorted.count
        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
        }
        return sorted[count / 2]
    }

    static func coefficientOfVariation(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        guard mean > 0 else { return 0 }
        let variance = values.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return sqrt(variance) / mean
    }
}
