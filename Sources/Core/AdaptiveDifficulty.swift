import Foundation

struct AdaptiveDifficulty {
    struct Config: Codable, Equatable {
        var windowSize: Int = 5
        var promoteThreshold: Double = 1.0
        var demoteThreshold: Double = 0.5
        var stabilityCV: Double = 0.15
    }

    enum Recommendation: Equatable {
        case promote(to: SchulteDifficulty)
        case demote(to: SchulteDifficulty)
        case stay
    }

    struct Evaluation: Equatable {
        let recommendation: Recommendation
        let currentMedianScore: Double?
        let currentCV: Double?
        let sessionsAtLevel: Int
        let windowSize: Int
    }

    static let defaultConfig = Config()

    static func baseDuration(for difficulty: SchulteDifficulty) -> TimeInterval {
        switch difficulty {
        case .easy3x3:      10
        case .focus4x4:     25
        case .challenge5x5: 40
        case .expert6x6:    60
        case .master7x7:    85
        case .elite8x8:     120
        case .legend9x9:    160
        }
    }

    static func sessionScore(result: SchulteSessionResult) -> Double {
        let base = baseDuration(for: result.difficulty)
        let tiles = Double(result.difficulty.totalTiles)
        let accuracy = max(0, 1.0 - (Double(result.mistakeCount) / tiles) * 0.5)
        return (base / max(result.duration, 1)) * accuracy
    }

    static func evaluate(
        currentDifficulty: SchulteDifficulty,
        history: [SchulteSessionResult],
        config: Config = defaultConfig
    ) -> Evaluation {
        let atLevel = history.filter { $0.difficulty == currentDifficulty }
        let window = Array(atLevel.prefix(config.windowSize))

        guard window.count >= config.windowSize else {
            return Evaluation(
                recommendation: .stay,
                currentMedianScore: window.isEmpty ? nil : median(window.map { sessionScore(result: $0) }),
                currentCV: nil,
                sessionsAtLevel: window.count,
                windowSize: config.windowSize
            )
        }

        let scores = window.map { sessionScore(result: $0) }
        let med = median(scores)
        let cv = coefficientOfVariation(scores)

        let recommendation: Recommendation
        if med >= config.promoteThreshold && cv < config.stabilityCV {
            if let next = currentDifficulty.harder {
                recommendation = .promote(to: next)
            } else {
                recommendation = .stay
            }
        } else if med < config.demoteThreshold {
            if let prev = currentDifficulty.easier {
                recommendation = .demote(to: prev)
            } else {
                recommendation = .stay
            }
        } else {
            recommendation = .stay
        }

        return Evaluation(
            recommendation: recommendation,
            currentMedianScore: med,
            currentCV: cv,
            sessionsAtLevel: window.count,
            windowSize: config.windowSize
        )
    }

    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let count = sorted.count
        if count == 0 { return 0 }
        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
        }
        return sorted[count / 2]
    }

    static func coefficientOfVariation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        guard mean > 0 else { return 0 }
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return sqrt(variance) / mean
    }
}
