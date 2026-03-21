import Foundation

struct AIAnalysisResult: Equatable {
    let content: String
    let generatedAt: Date
}

protocol AIProvider: Sendable {
    func complete(prompt: String) async throws -> String
}

actor AIAnalystService {
    private let provider: (any AIProvider)?

    init(provider: (any AIProvider)? = nil) {
        self.provider = provider
    }

    func analyzePerformance(sessions: [SessionResult]) async throws -> AIAnalysisResult {
        let profile = CognitiveProfile.compute(from: sessions)
        let prompt = AIPromptBuilder.buildAnalysisPrompt(sessions: sessions, profile: profile)

        guard let provider else {
            let localInsights = PerformanceInsightExtractor.extract(from: sessions)
            let fallback = buildLocalAnalysis(insights: localInsights, profile: profile)
            return AIAnalysisResult(content: fallback, generatedAt: Date())
        }

        let p = provider
        let response = try await p.complete(prompt: prompt)
        return AIAnalysisResult(content: response, generatedAt: Date())
    }

    func generateWeeklyReport(sessions: [SessionResult]) async throws -> AIAnalysisResult {
        let profile = CognitiveProfile.compute(from: sessions)
        let prompt = AIPromptBuilder.buildWeeklyReportPrompt(sessions: sessions, profile: profile)

        guard let provider else {
            let fallback = buildLocalWeeklyReport(sessions: sessions, profile: profile)
            return AIAnalysisResult(content: fallback, generatedAt: Date())
        }

        let p = provider
        let response = try await p.complete(prompt: prompt)
        return AIAnalysisResult(content: response, generatedAt: Date())
    }

    private func buildLocalAnalysis(insights: [PerformanceInsight], profile: CognitiveProfile) -> String {
        var lines: [String] = ["## 训练分析（本地生成）", ""]

        lines.append("### 认知画像")
        for dim in profile.dimensions {
            let bar = String(repeating: "█", count: Int(dim.score / 10))
            lines.append("- \(dim.name): \(bar) \(String(format: "%.0f", dim.score))")
        }

        if !insights.isEmpty {
            lines.append("")
            lines.append("### 洞察")
            for insight in insights {
                let icon: String
                switch insight.type {
                case .improving: icon = "↑"
                case .declining: icon = "↓"
                case .plateau:   icon = "→"
                case .newBest:   icon = "★"
                case .anomaly:   icon = "!"
                }
                lines.append("- \(icon) \(insight.message)")
            }
        }

        let scheduler = TrainingScheduler.recommend(sessions: [], allModules: TrainingModule.allCases, maxCount: 3)
        if !scheduler.isEmpty {
            lines.append("")
            lines.append("### 训练建议")
            for rec in scheduler {
                lines.append("- \(rec.module.displayName): \(rec.reason)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func buildLocalWeeklyReport(sessions: [SessionResult], profile: CognitiveProfile) -> String {
        let weekAgo = Date().addingTimeInterval(-7 * 86400)
        let thisWeek = sessions.filter { $0.startedAt >= weekAgo }
        let byModule = Dictionary(grouping: thisWeek) { $0.module }

        var lines: [String] = ["## 本周训练周报", ""]
        lines.append("本周完成 \(thisWeek.count) 次训练，涵盖 \(byModule.count) 个模块。")
        lines.append("")

        for (module, ms) in byModule.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            lines.append("- \(module.displayName): \(ms.count) 次")
        }

        let insights = PerformanceInsightExtractor.extract(from: sessions)
        if !insights.isEmpty {
            lines.append("")
            lines.append("### 趋势")
            for insight in insights.prefix(5) {
                lines.append("- \(insight.message)")
            }
        }

        return lines.joined(separator: "\n")
    }
}
