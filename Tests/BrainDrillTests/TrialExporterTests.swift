import Foundation
import Testing
@testable import BrainDrill

struct TrialExporterTests {
    @Test func csvHeaderContainsRequiredColumns() {
        let csv = TrialExporter.exportCSV(sessions: [])
        let header = csv.components(separatedBy: "\n").first ?? ""
        #expect(header.contains("session_id"))
        #expect(header.contains("module"))
        #expect(header.contains("started_at"))
        #expect(header.contains("duration"))
        #expect(header.contains("metric_key"))
        #expect(header.contains("metric_value"))
    }

    @Test func exportsSingleSession() {
        let now = Date()
        let session = SessionResult(
            module: .choiceRT, startedAt: now, endedAt: now, duration: 60,
            metrics: .choiceRT(ChoiceRTMetrics(totalTrials: 30, medianRT: 0.350, rtStandardDeviation: 0.05, accuracy: 0.90, postErrorSlowing: 0.02, anticipationCount: 1, choiceCount: 2))
        )
        let csv = TrialExporter.exportCSV(sessions: [session])
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count > 1)
        #expect(lines[1].contains("choiceRT"))
    }

    @Test func exportMultipleModules() {
        let now = Date()
        let sessions = [
            SessionResult(module: .digitSpan, startedAt: now, endedAt: now, duration: 120,
                          metrics: .digitSpan(DigitSpanMetrics(maxSpanForward: 7, maxSpanBackward: 5, totalTrials: 10, correctTrials: 8, accuracy: 0.8, positionErrors: 3))),
            SessionResult(module: .goNoGo, startedAt: now, endedAt: now, duration: 90,
                          metrics: .goNoGo(GoNoGoMetrics(totalTrials: 60, goRT: 0.35, goAccuracy: 0.95, noGoAccuracy: 0.85, dPrime: 2.5))),
        ]
        let csv = TrialExporter.exportCSV(sessions: sessions)
        #expect(csv.contains("digitSpan"))
        #expect(csv.contains("goNoGo"))
    }

    @Test func emptySessionsProducesHeaderOnly() {
        let csv = TrialExporter.exportCSV(sessions: [])
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 1)
    }
}
