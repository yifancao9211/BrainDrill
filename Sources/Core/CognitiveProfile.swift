import Foundation

struct CognitiveDimension: Identifiable, Equatable {
    let id: String
    let name: String
    let score: Double
}

struct CognitiveProfile: Equatable {
    let dimensions: [CognitiveDimension]

    static let dimensionDefinitions: [(id: String, name: String)] = [
        ("memoryCapacity", "记忆容量"),
        ("visualWorkingMemory", "视觉工作记忆"),
        ("logicalReasoning", "逻辑推理"),
    ]

    static func compute(from sessions: [SessionResult]) -> CognitiveProfile {
        let dims = dimensionDefinitions.map { def in
            CognitiveDimension(
                id: def.id,
                name: def.name,
                score: scoreForDimension(def.id, sessions: sessions)
            )
        }
        return CognitiveProfile(dimensions: dims)
    }

    private static func scoreForDimension(_ id: String, sessions: [SessionResult]) -> Double {
        switch id {
        case "memoryCapacity":
            return memoryCapacityScore(sessions)
        case "visualWorkingMemory":
            return visualWorkingMemoryScore(sessions)
        case "logicalReasoning":
            return logicalReasoningScore(sessions)
        default:
            return 0
        }
    }

    private static func memoryCapacityScore(_ sessions: [SessionResult]) -> Double {
        let spans = sessions.compactMap { s -> Int? in
            if let m = s.digitSpanMetrics { return max(m.maxSpanForward, m.maxSpanBackward) }
            if let m = s.corsiBlockMetrics { return m.maxSpan }
            return nil
        }
        guard let best = spans.max() else { return 0 }
        return clampScore(Double(best) / 9.0 * 100)
    }

    private static func visualWorkingMemoryScore(_ sessions: [SessionResult]) -> Double {
        let dPrimes = sessions.compactMap { $0.changeDetectionMetrics?.dPrime }
        guard let best = dPrimes.max() else { return 0 }
        return clampScore(best / 4.0 * 100)
    }

    private static func logicalReasoningScore(_ sessions: [SessionResult]) -> Double {
        var scores: [Double] = []

        // Syllogism: based on d'
        let syllogismDPrimes = sessions.compactMap { $0.syllogismMetrics?.dPrime }
        if let bestDP = syllogismDPrimes.max() {
            scores.append(clampScore(bestDP / 3.0 * 100))
        }

        // Logic Argument: based on composite score
        let argumentScores = sessions.compactMap { $0.logicArgumentMetrics?.compositeScore }
        if let bestScore = argumentScores.max() {
            scores.append(clampScore(bestScore * 100))
        }

        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    private static func clampScore(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}
