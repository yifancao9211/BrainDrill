import Foundation

struct TrainingStatistics {
    let totalSessions: Int
    let schulteCount: Int
    let flankerCount: Int
    let goNoGoCount: Int
    let nBackCount: Int
    let digitSpanCount: Int
    let choiceRTCount: Int
    let changeDetectionCount: Int
    let visualSearchCount: Int

    let bestSchulteTime: TimeInterval?
    let latestSchulteTime: TimeInterval?
    let recentSchulteAverage: TimeInterval?
    let mostPlayedDifficulty: SchulteDifficulty?
    let recentSchulteTrend: [SchulteTrendPoint]
    let recentImprovement: TimeInterval?

    let bestFlankerConflictCost: TimeInterval?
    let bestGoNoGoDPrime: Double?
    let bestNBackLevel: Int?

    let bestDigitSpan: Int?
    let bestChoiceRTMedian: TimeInterval?
    let bestChangeDetectionDPrime: Double?
    let bestVisualSearchSlope: TimeInterval?

    init(sessions: [SessionResult]) {
        totalSessions = sessions.count

        let schulte = sessions.filter { $0.module == .schulte }
        let flanker = sessions.filter { $0.module == .flanker }
        let goNoGo = sessions.filter { $0.module == .goNoGo }
        let nBack = sessions.filter { $0.module == .nBack }
        let dSpan = sessions.filter { $0.module == .digitSpan }
        let crt = sessions.filter { $0.module == .choiceRT }
        let cd = sessions.filter { $0.module == .changeDetection }
        let vs = sessions.filter { $0.module == .visualSearch }

        schulteCount = schulte.count
        flankerCount = flanker.count
        goNoGoCount = goNoGo.count
        nBackCount = nBack.count
        digitSpanCount = dSpan.count
        choiceRTCount = crt.count
        changeDetectionCount = cd.count
        visualSearchCount = vs.count

        bestSchulteTime = schulte.map(\.duration).min()
        latestSchulteTime = schulte.first?.duration
        let recent5 = schulte.prefix(5).map(\.duration)
        recentSchulteAverage = recent5.isEmpty ? nil : recent5.reduce(0, +) / Double(recent5.count)

        let grouped = Dictionary(grouping: schulte.compactMap { $0.schulteMetrics?.difficulty }) { $0 }
        mostPlayedDifficulty = grouped.max(by: { $0.value.count < $1.value.count })?.key

        recentSchulteTrend = Array(schulte.prefix(7).reversed()).enumerated().map { i, s in
            SchulteTrendPoint(
                index: i + 1,
                duration: s.duration,
                difficulty: s.schulteMetrics?.difficulty ?? .focus4x4
            )
        }

        if schulte.count > 1 {
            let baseline = Array(schulte.dropFirst().prefix(5)).map(\.duration)
            let avg = baseline.isEmpty ? nil : baseline.reduce(0, +) / Double(baseline.count)
            if let avg, let latest = schulte.first?.duration {
                recentImprovement = latest - avg
            } else {
                recentImprovement = nil
            }
        } else {
            recentImprovement = nil
        }

        bestFlankerConflictCost = flanker.compactMap { $0.flankerMetrics?.conflictCost }.min()
        bestGoNoGoDPrime = goNoGo.compactMap { $0.goNoGoMetrics?.dPrime }.max()
        bestNBackLevel = nBack.compactMap { $0.nBackMetrics?.nLevel }.max()

        let fwdSpans = dSpan.compactMap { $0.digitSpanMetrics?.maxSpanForward }
        let bwdSpans = dSpan.compactMap { $0.digitSpanMetrics?.maxSpanBackward }
        bestDigitSpan = (fwdSpans + bwdSpans).max()

        bestChoiceRTMedian = crt.compactMap { $0.choiceRTMetrics?.medianRT }.filter { $0 > 0 }.min()
        bestChangeDetectionDPrime = cd.compactMap { $0.changeDetectionMetrics?.dPrime }.max()
        bestVisualSearchSlope = vs.compactMap { $0.visualSearchMetrics?.searchSlope }.filter { $0 > 0 }.min()
    }

    func count(for module: TrainingModule) -> Int {
        switch module {
        case .schulte:         schulteCount
        case .flanker:         flankerCount
        case .goNoGo:          goNoGoCount
        case .nBack:           nBackCount
        case .digitSpan:       digitSpanCount
        case .choiceRT:        choiceRTCount
        case .changeDetection: changeDetectionCount
        case .visualSearch:    visualSearchCount
        }
    }
}

struct SchulteTrendPoint: Identifiable {
    let index: Int
    let duration: TimeInterval
    let difficulty: SchulteDifficulty

    var id: Int { index }
}
