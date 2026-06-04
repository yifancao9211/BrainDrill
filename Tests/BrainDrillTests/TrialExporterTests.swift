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
            module: .digitSpan, startedAt: now, endedAt: now, duration: 60,
            metrics: .digitSpan(DigitSpanMetrics(maxSpanForward: 7, maxSpanBackward: 5, totalTrials: 10, correctTrials: 8, accuracy: 0.8, positionErrors: 3))
        )
        let csv = TrialExporter.exportCSV(sessions: [session])
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count > 1)
        #expect(lines[1].contains("digitSpan"))
    }

    @Test func exportMultipleModules() {
        let now = Date()
        let sessions = [
            SessionResult(module: .digitSpan, startedAt: now, endedAt: now, duration: 120,
                          metrics: .digitSpan(DigitSpanMetrics(maxSpanForward: 7, maxSpanBackward: 5, totalTrials: 10, correctTrials: 8, accuracy: 0.8, positionErrors: 3))),
            SessionResult(module: .corsiBlock, startedAt: now, endedAt: now, duration: 90,
                          metrics: .corsiBlock(CorsiBlockMetrics(maxSpan: 5, totalTrials: 10, correctTrials: 8, accuracy: 0.8, positionErrors: 2, mode: .forward))),
        ]
        let csv = TrialExporter.exportCSV(sessions: sessions)
        #expect(csv.contains("digitSpan"))
        #expect(csv.contains("corsiBlock"))
    }

    @Test func emptySessionsProducesHeaderOnly() {
        let csv = TrialExporter.exportCSV(sessions: [])
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 1)
    }
}
