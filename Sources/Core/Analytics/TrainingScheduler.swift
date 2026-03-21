import Foundation

struct TrainingRecommendation: Identifiable, Equatable {
    let module: TrainingModule
    let priority: Double
    let reason: String

    var id: String { module.rawValue }
}

enum TrainingScheduler {
    static func recommend(
        sessions: [SessionResult],
        allModules: [TrainingModule],
        maxCount: Int = 5
    ) -> [TrainingRecommendation] {
        var scored: [(TrainingModule, Double, String)] = []

        for module in allModules {
            let moduleSessions = sessions.filter { $0.module == module }
            let (priority, reason) = computePriority(module: module, sessions: moduleSessions, allSessions: sessions)
            scored.append((module, priority, reason))
        }

        scored.sort { $0.1 > $1.1 }

        return scored.prefix(maxCount).map {
            TrainingRecommendation(module: $0.0, priority: $0.1, reason: $0.2)
        }
    }

    private static func computePriority(module: TrainingModule, sessions: [SessionResult], allSessions: [SessionResult]) -> (Double, String) {
        if sessions.isEmpty {
            return (100, "尚未训练过，建议尝试")
        }

        var priority = 50.0
        var reasons: [String] = []

        // Recency: longer since last training = higher priority
        if let lastDate = sessions.first?.endedAt {
            let daysSinceLast = Date().timeIntervalSince(lastDate) / 86400
            if daysSinceLast > 7 {
                priority += 30
                reasons.append("超过 \(Int(daysSinceLast)) 天未训练")
            } else if daysSinceLast > 3 {
                priority += 15
                reasons.append("\(Int(daysSinceLast)) 天未训练")
            } else if daysSinceLast < 1 {
                priority -= 20
            }
        }

        // Trend: declining performance = higher priority
        let recentScores = sessions.prefix(5).map { performanceScore($0) }
        if recentScores.count >= 3 {
            let trend = FatigueDetector.linearTrend(recentScores)
            if trend < -0.02 {
                priority += 25
                reasons.append("近期表现下降")
            } else if trend > 0.02 {
                priority -= 10
            }
        }

        // Frequency balance: less trained relative to others = higher priority
        let avgCount = Double(allSessions.count) / Double(max(TrainingModule.allCases.count, 1))
        if Double(sessions.count) < avgCount * 0.5 {
            priority += 15
            reasons.append("训练次数偏少")
        }

        let reason = reasons.isEmpty ? "维持训练频率" : reasons.joined(separator: "；")
        return (max(0, min(priority, 100)), reason)
    }

    private static func performanceScore(_ session: SessionResult) -> Double {
        switch session.metrics {
        case let .choiceRT(m):        return m.accuracy * (1.0 - m.medianRT)
        case let .goNoGo(m):          return m.dPrime / 4.0
        case let .flanker(m):         return m.accuracy * (1.0 - m.conflictCost)
        case let .digitSpan(m):       return Double(max(m.maxSpanForward, m.maxSpanBackward)) / 9.0
        case let .changeDetection(m): return m.dPrime / 4.0
        case let .visualSearch(m):    return m.accuracy
        case let .nBack(m):           return m.dPrime / 4.0
        case let .stopSignal(m):      return m.inhibitionRate
        case let .corsiBlock(m):      return Double(m.maxSpan) / 9.0
        case .schulte:                return 0.5
        }
    }
}
