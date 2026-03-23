import Foundation

enum TrialExporter {
    static func exportCSV(sessions: [SessionResult]) -> String {
        var lines: [String] = []
        lines.append("session_id,module,started_at,duration,metric_key,metric_value")

        let formatter = ISO8601DateFormatter()

        for session in sessions {
            let sid = session.id.uuidString
            let mod = session.module.rawValue
            let date = formatter.string(from: session.startedAt)
            let dur = String(format: "%.3f", session.duration)

            let kvPairs = metricsToKeyValues(session.metrics)
            for (key, value) in kvPairs {
                lines.append("\(sid),\(mod),\(date),\(dur),\(key),\(value)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func metricsToKeyValues(_ metrics: ModuleMetrics) -> [(String, String)] {
        switch metrics {
        case let .mainIdea(m):
            return [
                ("passageID", m.passageID),
                ("difficulty", "\(m.difficulty)"),
                ("isCorrect", m.isCorrect ? "1" : "0"),
                ("readingDuration", String(format: "%.4f", m.readingDuration)),
                ("responseDuration", String(format: "%.4f", m.responseDuration)),
            ]
        case let .evidenceMap(m):
            return [
                ("passageID", m.passageID),
                ("difficulty", "\(m.difficulty)"),
                ("correctItems", "\(m.correctItems)"),
                ("totalItems", "\(m.totalItems)"),
                ("accuracy", String(format: "%.4f", m.accuracy)),
                ("falseSelections", "\(m.falseSelections)"),
            ]
        case let .delayedRecall(m):
            return [
                ("passageID", m.passageID),
                ("difficulty", "\(m.difficulty)"),
                ("recalledTargets", "\(m.recalledTargets)"),
                ("totalTargets", "\(m.totalTargets)"),
                ("accuracy", String(format: "%.4f", m.accuracy)),
                ("intrusionCount", "\(m.intrusionCount)"),
            ]
        case let .schulte(m):
            return [
                ("difficulty", m.difficulty.rawValue),
                ("mistakeCount", "\(m.mistakeCount)"),
            ]
        case let .flanker(m):
            return [
                ("totalTrials", "\(m.totalTrials)"),
                ("conflictCost", String(format: "%.4f", m.conflictCost)),
                ("accuracy", String(format: "%.4f", m.accuracy)),
            ]
        case let .goNoGo(m):
            return [
                ("totalTrials", "\(m.totalTrials)"),
                ("goRT", String(format: "%.4f", m.goRT)),
                ("dPrime", String(format: "%.4f", m.dPrime)),
                ("noGoAccuracy", String(format: "%.4f", m.noGoAccuracy)),
            ]
        case let .nBack(m):
            return [
                ("nLevel", "\(m.nLevel)"),
                ("dPrime", String(format: "%.4f", m.dPrime)),
                ("hitRate", String(format: "%.4f", m.hitRate)),
            ]
        case let .digitSpan(m):
            return [
                ("maxSpanForward", "\(m.maxSpanForward)"),
                ("maxSpanBackward", "\(m.maxSpanBackward)"),
                ("accuracy", String(format: "%.4f", m.accuracy)),
                ("positionErrors", "\(m.positionErrors)"),
            ]
        case let .choiceRT(m):
            return [
                ("totalTrials", "\(m.totalTrials)"),
                ("medianRT", String(format: "%.4f", m.medianRT)),
                ("rtSD", String(format: "%.4f", m.rtStandardDeviation)),
                ("accuracy", String(format: "%.4f", m.accuracy)),
                ("postErrorSlowing", String(format: "%.4f", m.postErrorSlowing)),
            ]
        case let .changeDetection(m):
            return [
                ("totalTrials", "\(m.totalTrials)"),
                ("dPrime", String(format: "%.4f", m.dPrime)),
                ("accuracy", String(format: "%.4f", m.accuracy)),
                ("maxSetSize", "\(m.maxSetSize)"),
            ]
        case let .visualSearch(m):
            return [
                ("totalTrials", "\(m.totalTrials)"),
                ("searchSlope", String(format: "%.4f", m.searchSlope)),
                ("accuracy", String(format: "%.4f", m.accuracy)),
            ]
        case let .corsiBlock(m):
            return [
                ("maxSpan", "\(m.maxSpan)"),
                ("accuracy", String(format: "%.4f", m.accuracy)),
                ("positionErrors", "\(m.positionErrors)"),
            ]
        case let .stopSignal(m):
            return [
                ("totalTrials", "\(m.totalTrials)"),
                ("goRT", String(format: "%.4f", m.goRT)),
                ("ssrt", String(format: "%.4f", m.ssrt)),
                ("inhibitionRate", String(format: "%.4f", m.inhibitionRate)),
            ]
        }
    }
}
