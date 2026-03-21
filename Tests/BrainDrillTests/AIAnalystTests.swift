import Foundation
import Testing
@testable import BrainDrill

struct PerformanceInsightTests {
    @Test func extractsInsightsFromSessions() {
        let now = Date()
        let sessions = (0..<5).map { i in
            SessionResult(module: .choiceRT, startedAt: now.addingTimeInterval(Double(-i) * 86400), endedAt: now, duration: 60,
                          metrics: .choiceRT(ChoiceRTMetrics(totalTrials: 30, medianRT: 0.35 - Double(i) * 0.02, rtStandardDeviation: 0.04, accuracy: 0.90, postErrorSlowing: 0.02, anticipationCount: 0, choiceCount: 2)))
        }
        let insights = PerformanceInsightExtractor.extract(from: sessions)
        #expect(!insights.isEmpty)
    }

    @Test func detectsImprovementTrend() {
        let now = Date()
        let sessions = (0..<8).map { i in
            SessionResult(module: .goNoGo, startedAt: now.addingTimeInterval(Double(-i) * 86400), endedAt: now, duration: 90,
                          metrics: .goNoGo(GoNoGoMetrics(totalTrials: 60, goRT: 0.35, goAccuracy: 0.95, noGoAccuracy: 0.80 + Double(i) * 0.02, dPrime: 2.0 + Double(i) * 0.2)))
        }
        let insights = PerformanceInsightExtractor.extract(from: sessions)
        let improving = insights.filter { $0.type == .improving }
        #expect(!improving.isEmpty)
    }

    @Test func detectsPlateau() {
        let now = Date()
        let sessions = (0..<8).map { i in
            SessionResult(module: .digitSpan, startedAt: now.addingTimeInterval(Double(-i) * 86400), endedAt: now, duration: 120,
                          metrics: .digitSpan(DigitSpanMetrics(maxSpanForward: 6, maxSpanBackward: 4, totalTrials: 10, correctTrials: 8, accuracy: 0.8, positionErrors: 2)))
        }
        let insights = PerformanceInsightExtractor.extract(from: sessions)
        let plateau = insights.filter { $0.type == .plateau }
        #expect(!plateau.isEmpty)
    }

    @Test func emptySessionsReturnsEmpty() {
        let insights = PerformanceInsightExtractor.extract(from: [])
        #expect(insights.isEmpty)
    }
}

struct AIPromptBuilderTests {
    @Test func buildsPromptWithSessionData() {
        let now = Date()
        let sessions = [
            SessionResult(module: .choiceRT, startedAt: now, endedAt: now, duration: 60,
                          metrics: .choiceRT(ChoiceRTMetrics(totalTrials: 30, medianRT: 0.35, rtStandardDeviation: 0.04, accuracy: 0.90, postErrorSlowing: 0.02, anticipationCount: 0, choiceCount: 2))),
        ]
        let prompt = AIPromptBuilder.buildAnalysisPrompt(sessions: sessions, profile: CognitiveProfile.compute(from: sessions))
        #expect(prompt.contains("选择反应时"))
        #expect(prompt.contains("350ms"))
    }

    @Test func buildsWeeklyReportPrompt() {
        let now = Date()
        let sessions = (0..<3).map { i in
            SessionResult(module: .goNoGo, startedAt: now.addingTimeInterval(Double(-i) * 86400), endedAt: now, duration: 90,
                          metrics: .goNoGo(GoNoGoMetrics(totalTrials: 60, goRT: 0.35, goAccuracy: 0.95, noGoAccuracy: 0.85, dPrime: 2.5)))
        }
        let prompt = AIPromptBuilder.buildWeeklyReportPrompt(sessions: sessions, profile: CognitiveProfile.compute(from: sessions))
        #expect(prompt.contains("周报"))
        #expect(prompt.contains("Go/No-Go"))
    }

    @Test func emptySessionsStillBuildsPrompt() {
        let prompt = AIPromptBuilder.buildAnalysisPrompt(sessions: [], profile: CognitiveProfile.compute(from: []))
        #expect(!prompt.isEmpty)
    }
}
