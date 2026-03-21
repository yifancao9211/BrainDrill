import Foundation

enum InsightType: Equatable {
    case improving
    case declining
    case plateau
    case newBest
    case anomaly
}

struct PerformanceInsight: Identifiable, Equatable {
    let id: String
    let module: TrainingModule
    let type: InsightType
    let message: String
    let metric: String
    let value: Double
}

enum PerformanceInsightExtractor {
    static let minimumSessions = 3

    static func extract(from sessions: [SessionResult]) -> [PerformanceInsight] {
        guard !sessions.isEmpty else { return [] }

        var insights: [PerformanceInsight] = []
        let byModule = Dictionary(grouping: sessions) { $0.module }

        for (module, moduleSessions) in byModule {
            let sorted = moduleSessions.sorted { $0.endedAt > $1.endedAt }
            guard sorted.count >= minimumSessions else { continue }

            let scores = sorted.prefix(8).map { performanceScore($0) }
            let trend = FatigueDetector.linearTrend(scores)
            let cv = MetricsCalculator.coefficientOfVariation(scores)

            if trend > 0.02 {
                insights.append(PerformanceInsight(
                    id: "\(module.rawValue)-improving",
                    module: module,
                    type: .improving,
                    message: "\(module.displayName) 近期持续进步",
                    metric: "趋势斜率",
                    value: trend
                ))
            } else if trend < -0.02 {
                insights.append(PerformanceInsight(
                    id: "\(module.rawValue)-declining",
                    module: module,
                    type: .declining,
                    message: "\(module.displayName) 近期表现下降",
                    metric: "趋势斜率",
                    value: trend
                ))
            } else if cv < 0.05 && sorted.count >= 5 {
                insights.append(PerformanceInsight(
                    id: "\(module.rawValue)-plateau",
                    module: module,
                    type: .plateau,
                    message: "\(module.displayName) 已进入平台期",
                    metric: "变异系数",
                    value: cv
                ))
            }
        }

        return insights
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
