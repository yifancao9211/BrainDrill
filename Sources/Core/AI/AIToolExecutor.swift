import Foundation

enum AIToolExecutor {
    static func execute(name: String, arguments: [String: Any], sessions: [SessionResult]) -> String {
        switch name {
        case "get_cognitive_profile":
            return cognitiveProfile(sessions)
        case "get_module_history":
            let module = arguments["module"] as? String ?? ""
            let limit = arguments["limit"] as? Int ?? 5
            return moduleHistory(sessions, module: module, limit: limit)
        case "get_performance_trend":
            let module = arguments["module"] as? String ?? ""
            return performanceTrend(sessions, module: module)
        case "get_anomalies":
            return anomalies(sessions)
        case "get_fatigue_status":
            return fatigueStatus(sessions)
        case "get_time_of_day_analysis":
            return timeOfDay(sessions)
        case "get_training_recommendations":
            return recommendations(sessions)
        case "get_statistics":
            return statistics(sessions)
        default:
            return "{\"error\": \"unknown tool: \(name)\"}"
        }
    }

    private static func cognitiveProfile(_ sessions: [SessionResult]) -> String {
        let profile = CognitiveProfile.compute(from: sessions)
        let dims = profile.dimensions.map { "{\"name\":\"\($0.name)\",\"score\":\(String(format: "%.1f", $0.score))}" }
        return "{\"dimensions\":[\(dims.joined(separator: ","))]}"
    }

    private static func moduleHistory(_ sessions: [SessionResult], module: String, limit: Int) -> String {
        guard let mod = TrainingModule(rawValue: module) else {
            return "{\"error\":\"unknown module: \(module)\"}"
        }
        let filtered = sessions.filter { $0.module == mod }.prefix(limit)
        let items = filtered.map { s in
            let metrics = formatMetrics(s.metrics)
            return "{\"date\":\"\(ISO8601DateFormatter().string(from: s.startedAt))\",\"duration\":\(String(format: "%.0f", s.duration)),\"metrics\":\(metrics)}"
        }
        return "{\"module\":\"\(mod.displayName)\",\"count\":\(filtered.count),\"records\":[\(items.joined(separator: ","))]}"
    }

    private static func performanceTrend(_ sessions: [SessionResult], module: String) -> String {
        guard let mod = TrainingModule(rawValue: module) else {
            return "{\"error\":\"unknown module\"}"
        }
        let insights = PerformanceInsightExtractor.extract(from: sessions)
        let relevant = insights.filter { $0.module == mod }
        if let insight = relevant.first {
            let typeStr: String
            switch insight.type {
            case .improving: typeStr = "improving"
            case .declining: typeStr = "declining"
            case .plateau:   typeStr = "plateau"
            case .newBest:   typeStr = "new_best"
            case .anomaly:   typeStr = "anomaly"
            }
            return "{\"module\":\"\(mod.displayName)\",\"trend\":\"\(typeStr)\",\"message\":\"\(insight.message)\"}"
        }
        let count = sessions.filter { $0.module == mod }.count
        return "{\"module\":\"\(mod.displayName)\",\"trend\":\"insufficient_data\",\"sessionCount\":\(count)}"
    }

    private static func anomalies(_ sessions: [SessionResult]) -> String {
        guard let latest = sessions.first else {
            return "{\"anomalies\":[]}"
        }
        let result = AnomalyDetector.check(latest: latest, history: Array(sessions.dropFirst()))
        if result.isAnomalous {
            let items = result.anomalies.map { "{\"metric\":\"\($0.metric)\",\"message\":\"\($0.message)\",\"deviations\":\(String(format: "%.1f", $0.deviations))}" }
            return "{\"isAnomalous\":true,\"anomalies\":[\(items.joined(separator: ","))]}"
        }
        return "{\"isAnomalous\":false,\"anomalies\":[]}"
    }

    private static func fatigueStatus(_ sessions: [SessionResult]) -> String {
        let recentRT = sessions.prefix(10).compactMap { s -> TimeInterval? in
            switch s.metrics {
            case let .choiceRT(m): return m.medianRT
            case let .goNoGo(m):  return m.goRT
            case let .flanker(m): return (m.congruentRT + m.incongruentRT) / 2
            default: return nil
            }
        }
        let recentAcc = sessions.prefix(10).compactMap { s -> Double? in
            switch s.metrics {
            case let .choiceRT(m): return m.accuracy
            case let .goNoGo(m):  return m.goAccuracy
            case let .flanker(m): return m.accuracy
            default: return nil
            }
        }
        let eval = FatigueDetector.evaluate(recentRTs: recentRT, recentAccuracies: recentAcc)
        return "{\"isFatigued\":\(eval.isFatigued),\"rtTrend\":\(String(format: "%.4f", eval.rtTrend)),\"accuracyTrend\":\(String(format: "%.4f", eval.accuracyTrend)),\"message\":\"\(eval.message ?? "状态良好")\"}"
    }

    private static func timeOfDay(_ sessions: [SessionResult]) -> String {
        let analysis = TimeOfDayAnalyzer.analyze(sessions: sessions)
        let slots = analysis.slots.map { "{\"name\":\"\($0.name)\",\"sessions\":\($0.sessionCount),\"score\":\(String(format: "%.2f", $0.averageScore))}" }
        let best = analysis.bestSlot?.name ?? "未知"
        return "{\"slots\":[\(slots.joined(separator: ","))],\"bestSlot\":\"\(best)\"}"
    }

    private static func recommendations(_ sessions: [SessionResult]) -> String {
        let recs = TrainingScheduler.recommend(sessions: sessions, allModules: TrainingModule.allCases, maxCount: 4)
        let items = recs.map { "{\"module\":\"\($0.module.displayName)\",\"priority\":\(String(format: "%.0f", $0.priority)),\"reason\":\"\($0.reason)\"}" }
        return "{\"recommendations\":[\(items.joined(separator: ","))]}"
    }

    private static func statistics(_ sessions: [SessionResult]) -> String {
        let stats = TrainingStatistics(sessions: sessions)
        var parts: [String] = []
        parts.append("\"totalSessions\":\(stats.totalSessions)")
        for mod in TrainingModule.allCases {
            let c = stats.count(for: mod)
            if c > 0 { parts.append("\"\(mod.rawValue)\":\(c)") }
        }
        if let t = stats.bestSchulteTime { parts.append("\"bestSchulteTime\":\(String(format: "%.1f", t))") }
        if let d = stats.bestGoNoGoDPrime { parts.append("\"bestGoNoGoDPrime\":\(String(format: "%.2f", d))") }
        if let n = stats.bestNBackLevel { parts.append("\"bestNBackLevel\":\(n)") }
        if let s = stats.bestDigitSpan { parts.append("\"bestDigitSpan\":\(s)") }
        if let r = stats.bestChoiceRTMedian { parts.append("\"bestChoiceRT\":\(String(format: "%.0f", r * 1000))") }
        if let d = stats.bestChangeDetectionDPrime { parts.append("\"bestChangeDetectionDPrime\":\(String(format: "%.2f", d))") }
        if let s = stats.bestVisualSearchSlope { parts.append("\"bestVisualSearchSlope\":\(String(format: "%.1f", s * 1000))") }
        if let c = stats.bestCorsiSpan { parts.append("\"bestCorsiSpan\":\(c)") }
        if let s = stats.bestSSRT { parts.append("\"bestSSRT\":\(String(format: "%.0f", s * 1000))") }
        return "{\(parts.joined(separator: ","))}"
    }

    private static func formatMetrics(_ metrics: ModuleMetrics) -> String {
        switch metrics {
        case let .schulte(m):         return "{\"difficulty\":\"\(m.difficulty.rawValue)\",\"mistakes\":\(m.mistakeCount)}"
        case let .flanker(m):         return "{\"conflictCost\":\(String(format: "%.0f", m.conflictCost * 1000)),\"accuracy\":\(String(format: "%.2f", m.accuracy))}"
        case let .goNoGo(m):          return "{\"dPrime\":\(String(format: "%.2f", m.dPrime)),\"goRT\":\(String(format: "%.0f", m.goRT * 1000)),\"noGoAccuracy\":\(String(format: "%.2f", m.noGoAccuracy))}"
        case let .nBack(m):           return "{\"nLevel\":\(m.nLevel),\"dPrime\":\(String(format: "%.2f", m.dPrime)),\"hitRate\":\(String(format: "%.2f", m.hitRate))}"
        case let .digitSpan(m):       return "{\"maxForward\":\(m.maxSpanForward),\"maxBackward\":\(m.maxSpanBackward),\"accuracy\":\(String(format: "%.2f", m.accuracy))}"
        case let .choiceRT(m):        return "{\"medianRT\":\(String(format: "%.0f", m.medianRT * 1000)),\"accuracy\":\(String(format: "%.2f", m.accuracy)),\"rtSD\":\(String(format: "%.0f", m.rtStandardDeviation * 1000))}"
        case let .changeDetection(m): return "{\"dPrime\":\(String(format: "%.2f", m.dPrime)),\"accuracy\":\(String(format: "%.2f", m.accuracy)),\"maxSetSize\":\(m.maxSetSize)}"
        case let .visualSearch(m):    return "{\"slope\":\(String(format: "%.1f", m.searchSlope * 1000)),\"accuracy\":\(String(format: "%.2f", m.accuracy))}"
        case let .corsiBlock(m):      return "{\"maxSpan\":\(m.maxSpan),\"accuracy\":\(String(format: "%.2f", m.accuracy))}"
        case let .stopSignal(m):      return "{\"ssrt\":\(String(format: "%.0f", m.ssrt * 1000)),\"inhibitionRate\":\(String(format: "%.2f", m.inhibitionRate)),\"goRT\":\(String(format: "%.0f", m.goRT * 1000))}"
        }
    }
}
