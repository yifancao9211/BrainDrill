import Foundation

enum AIPromptBuilder {
    static func buildAnalysisPrompt(sessions: [SessionResult], profile: CognitiveProfile) -> String {
        var sections: [String] = []

        sections.append("你是一位认知科学训练分析师。请基于以下用户训练数据，给出专业、具体的分析和建议。")
        sections.append("")

        sections.append("## 认知画像")
        for dim in profile.dimensions {
            sections.append("- \(dim.name): \(String(format: "%.0f", dim.score))/100")
        }
        sections.append("")

        sections.append("## 近期训练数据")
        let recent = sessions.prefix(20)
        let byModule = Dictionary(grouping: recent) { $0.module }

        for (module, moduleSessions) in byModule.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            sections.append("### \(module.displayName)（\(moduleSessions.count) 次）")
            for session in moduleSessions.prefix(5) {
                sections.append("  - \(formatMetrics(session.metrics))  时长:\(String(format: "%.0f", session.duration))s")
            }
        }

        sections.append("")
        sections.append("## 请分析以下方面")
        sections.append("1. 各维度的强弱项和变化趋势")
        sections.append("2. 跨模块的关联模式（如反应速度和抑制控制的关系）")
        sections.append("3. 具体可操作的训练建议（练什么、怎么练、练多久）")
        sections.append("4. 需要注意的异常或潜在问题")

        return sections.joined(separator: "\n")
    }

    static func buildWeeklyReportPrompt(sessions: [SessionResult], profile: CognitiveProfile) -> String {
        let weekAgo = Date().addingTimeInterval(-7 * 86400)
        let thisWeek = sessions.filter { $0.startedAt >= weekAgo }
        let lastWeek = sessions.filter { $0.startedAt >= weekAgo.addingTimeInterval(-7 * 86400) && $0.startedAt < weekAgo }

        var sections: [String] = []

        sections.append("你是一位认知训练教练。请根据用户本周和上周的训练数据，生成一份简洁的周报。")
        sections.append("")
        sections.append("## 本周训练（\(thisWeek.count) 次）")

        let thisWeekByModule = Dictionary(grouping: thisWeek) { $0.module }
        for (module, ms) in thisWeekByModule.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            sections.append("- \(module.displayName): \(ms.count) 次")
            for s in ms.prefix(3) {
                sections.append("  \(formatMetrics(s.metrics))")
            }
        }

        sections.append("")
        sections.append("## 上周训练（\(lastWeek.count) 次）")
        let lastWeekByModule = Dictionary(grouping: lastWeek) { $0.module }
        for (module, ms) in lastWeekByModule.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            sections.append("- \(module.displayName): \(ms.count) 次")
        }

        sections.append("")
        sections.append("## 认知画像")
        for dim in profile.dimensions {
            sections.append("- \(dim.name): \(String(format: "%.0f", dim.score))/100")
        }

        sections.append("")
        sections.append("## 请生成周报，包含：")
        sections.append("1. 本周训练概况（一段话）")
        sections.append("2. 与上周的对比变化")
        sections.append("3. 最显著的进步和需要关注的问题")
        sections.append("4. 下周训练建议")

        return sections.joined(separator: "\n")
    }

    private static func formatMetrics(_ metrics: ModuleMetrics) -> String {
        switch metrics {
        case let .choiceRT(m):        return "RT:\(String(format: "%.0f", m.medianRT * 1000))ms 正确率:\(String(format: "%.0f", m.accuracy * 100))%"
        case let .goNoGo(m):          return "d':\(String(format: "%.2f", m.dPrime)) GoRT:\(String(format: "%.0f", m.goRT * 1000))ms"
        case let .flanker(m):         return "冲突代价:\(String(format: "%.0f", m.conflictCost * 1000))ms 正确率:\(String(format: "%.0f", m.accuracy * 100))%"
        case let .digitSpan(m):       return "正背:\(m.maxSpanForward) 倒背:\(m.maxSpanBackward)"
        case let .changeDetection(m): return "d':\(String(format: "%.2f", m.dPrime)) 集合:\(m.maxSetSize)"
        case let .visualSearch(m):    return "斜率:\(String(format: "%.0f", m.searchSlope * 1000))ms/项 正确率:\(String(format: "%.0f", m.accuracy * 100))%"
        case let .nBack(m):           return "\(m.nLevel)-Back d':\(String(format: "%.2f", m.dPrime))"
        case let .stopSignal(m):      return "SSRT:\(String(format: "%.0f", m.ssrt * 1000))ms 抑制率:\(String(format: "%.0f", m.inhibitionRate * 100))%"
        case let .corsiBlock(m):      return "广度:\(m.maxSpan) \(m.mode.displayName)"
        case let .schulte(m):         return "\(m.difficulty.rawValue) 错误:\(m.mistakeCount)"
        }
    }
}
