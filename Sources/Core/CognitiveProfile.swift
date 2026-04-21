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
        ("reactionSpeed", "反应速度"),
        ("inhibitionControl", "抑制控制"),
        ("visualSearch", "视觉搜索"),
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
        case "reactionSpeed":
            return reactionSpeedScore(sessions)
        case "inhibitionControl":
            return inhibitionControlScore(sessions)
        case "visualSearch":
            return visualSearchScore(sessions)
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

    private static func reactionSpeedScore(_ sessions: [SessionResult]) -> Double {
        let rts = sessions.compactMap { $0.choiceRTMetrics?.medianRT }
        guard let best = rts.min() else { return 0 }
        // 200ms = 100, 600ms = 0, linear interpolation
        return clampScore((0.6 - best) / 0.4 * 100)
    }

    private static func inhibitionControlScore(_ sessions: [SessionResult]) -> Double {
        let goNoGoDPrimes = sessions.compactMap { $0.goNoGoMetrics?.dPrime }
        let stopSSRTs = sessions.compactMap { $0.stopSignalMetrics?.ssrt }
        let flankerCosts = sessions.compactMap { $0.flankerMetrics?.conflictCost }

        var scores: [Double] = []

        if let bestDP = goNoGoDPrimes.max() {
            scores.append(clampScore(bestDP / 4.0 * 100))
        }
        if let bestSSRT = stopSSRTs.min() {
            scores.append(clampScore((0.4 - bestSSRT) / 0.3 * 100))
        }
        if let bestCost = flankerCosts.min() {
            scores.append(clampScore((0.15 - bestCost) / 0.15 * 100))
        }

        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    private static func visualSearchScore(_ sessions: [SessionResult]) -> Double {
        let slopes = sessions.compactMap { $0.visualSearchMetrics?.searchSlope }
        guard let best = slopes.filter({ $0 > 0 }).min() else { return 0 }
        // 10ms/item = 100, 60ms/item = 0
        return clampScore((0.060 - best) / 0.050 * 100)
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
