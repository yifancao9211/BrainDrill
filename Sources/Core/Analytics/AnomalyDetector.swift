import Foundation

struct AnomalyResult: Equatable {
    let isAnomalous: Bool
    let anomalies: [AnomalyDetail]
}

struct AnomalyDetail: Equatable {
    let metric: String
    let currentValue: Double
    let historicalMean: Double
    let deviations: Double
    let message: String
}

enum AnomalyDetector {
    static let minimumHistory = 3
    static let zThreshold = 2.0

    static func check(latest: SessionResult, history: [SessionResult]) -> AnomalyResult {
        let sameModule = history.filter { $0.module == latest.module }
        guard sameModule.count >= minimumHistory else {
            return AnomalyResult(isAnomalous: false, anomalies: [])
        }

        var anomalies: [AnomalyDetail] = []

        let pairs = extractMetrics(from: latest, history: sameModule)
        for (name, current, historicals) in pairs {
            guard historicals.count >= minimumHistory else { continue }
            let mean = historicals.reduce(0, +) / Double(historicals.count)
            let sd = MetricsCalculator.standardDeviation(historicals)
            guard sd > 0 else { continue }

            let z = abs(current - mean) / sd
            if z > zThreshold {
                let direction = current > mean ? "高于" : "低于"
                anomalies.append(AnomalyDetail(
                    metric: name,
                    currentValue: current,
                    historicalMean: mean,
                    deviations: z,
                    message: "\(name)\(direction)历史均值 \(String(format: "%.1f", z)) 个标准差"
                ))
            }
        }

        return AnomalyResult(isAnomalous: !anomalies.isEmpty, anomalies: anomalies)
    }

    private static func extractMetrics(from latest: SessionResult, history: [SessionResult]) -> [(String, Double, [Double])] {
        var result: [(String, Double, [Double])] = []

        switch latest.metrics {
        case let .mainIdea(m):
            result.append(("主旨命中", m.isCorrect ? 1 : 0, history.compactMap { $0.mainIdeaMetrics.map { $0.isCorrect ? 1 : 0 } }))
        case let .evidenceMap(m):
            result.append(("结构准确率", m.accuracy, history.compactMap { $0.evidenceMapMetrics?.accuracy }))
        case let .delayedRecall(m):
            result.append(("回忆命中率", m.accuracy, history.compactMap { $0.delayedRecallMetrics?.accuracy }))
        case let .choiceRT(m):
            result.append(("中位RT", m.medianRT, history.compactMap { $0.choiceRTMetrics?.medianRT }))
            result.append(("正确率", m.accuracy, history.compactMap { $0.choiceRTMetrics?.accuracy }))
        case let .goNoGo(m):
            result.append(("d'", m.dPrime, history.compactMap { $0.goNoGoMetrics?.dPrime }))
            result.append(("Go RT", m.goRT, history.compactMap { $0.goNoGoMetrics?.goRT }))
        case let .flanker(m):
            result.append(("冲突代价", m.conflictCost, history.compactMap { $0.flankerMetrics?.conflictCost }))
            result.append(("正确率", m.accuracy, history.compactMap { $0.flankerMetrics?.accuracy }))
        case let .digitSpan(m):
            result.append(("正确率", m.accuracy, history.compactMap { $0.digitSpanMetrics?.accuracy }))
        case let .changeDetection(m):
            result.append(("d'", m.dPrime, history.compactMap { $0.changeDetectionMetrics?.dPrime }))
        case let .visualSearch(m):
            result.append(("搜索斜率", m.searchSlope, history.compactMap { $0.visualSearchMetrics?.searchSlope }))
        case let .schulte(m):
            result.append(("错误数", Double(m.mistakeCount), history.compactMap { $0.schulteMetrics.map { Double($0.mistakeCount) } }))
        case let .stopSignal(m):
            result.append(("SSRT", m.ssrt, history.compactMap { $0.stopSignalMetrics?.ssrt }))
        case let .corsiBlock(m):
            result.append(("正确率", m.accuracy, history.compactMap { $0.corsiBlockMetrics?.accuracy }))
        case let .nBack(m):
            result.append(("d'", m.dPrime, history.compactMap { $0.nBackMetrics?.dPrime }))
        }

        return result
    }
}
