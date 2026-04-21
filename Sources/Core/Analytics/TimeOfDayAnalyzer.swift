import Foundation

struct TimeSlot: Identifiable, Equatable {
    let name: String
    let hourRange: ClosedRange<Int>
    let sessionCount: Int
    let averageScore: Double

    var id: String { name }

    static let definitions: [(name: String, range: ClosedRange<Int>)] = [
        ("早晨", 6...8),
        ("上午", 9...11),
        ("下午", 12...16),
        ("傍晚", 17...19),
        ("夜晚", 20...23),
    ]
}

struct TimeOfDayAnalysis: Equatable {
    let slots: [TimeSlot]
    let bestSlot: TimeSlot?
}

enum TimeOfDayAnalyzer {
    static func analyze(sessions: [SessionResult]) -> TimeOfDayAnalysis {
        guard !sessions.isEmpty else {
            return TimeOfDayAnalysis(slots: [], bestSlot: nil)
        }

        let cal = Calendar.current
        var slotSessions: [String: [Double]] = [:]

        for session in sessions {
            let hour = cal.component(.hour, from: session.startedAt)
            if let slot = TimeSlot.definitions.first(where: { $0.range.contains(hour) }) {
                let score = performanceScore(session)
                slotSessions[slot.name, default: []].append(score)
            }
        }

        let slots = TimeSlot.definitions.compactMap { def -> TimeSlot? in
            guard let scores = slotSessions[def.name], !scores.isEmpty else { return nil }
            let avg = scores.reduce(0, +) / Double(scores.count)
            return TimeSlot(name: def.name, hourRange: def.range, sessionCount: scores.count, averageScore: avg)
        }

        let best = slots.filter { $0.sessionCount >= 2 }.max(by: { $0.averageScore < $1.averageScore })

        return TimeOfDayAnalysis(slots: slots, bestSlot: best)
    }

    private static func performanceScore(_ session: SessionResult) -> Double {
        switch session.metrics {
        case let .mainIdea(m):        return m.isCorrect ? 1.0 : 0.0
        case let .evidenceMap(m):     return m.accuracy
        case let .delayedRecall(m):   return m.accuracy
        case let .choiceRT(m):        return (1.0 - m.medianRT) * m.accuracy
        case let .goNoGo(m):          return m.dPrime / 4.0
        case let .flanker(m):         return (1.0 - m.conflictCost) * m.accuracy
        case let .digitSpan(m):       return Double(max(m.maxSpanForward, m.maxSpanBackward)) / 9.0
        case let .changeDetection(m): return m.dPrime / 4.0
        case let .visualSearch(m):    return (1.0 - m.searchSlope * 10) * m.accuracy
        case let .nBack(m):           return m.dPrime / 4.0
        case let .stopSignal(m):      return (1.0 - m.ssrt) * m.inhibitionRate
        case let .corsiBlock(m):      return Double(m.maxSpan) / 9.0
        case let .syllogism(m):       return m.accuracy
        case let .logicArgument(m):   return m.compositeScore
        case .schulte:                return 0.5
        }
    }
}
