import Foundation

enum SchulteDifficulty: String, CaseIterable, Codable, Identifiable {
    case easy3x3
    case focus4x4
    case challenge5x5

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy3x3:
            "热身 3x3"
        case .focus4x4:
            "经典 4x4"
        case .challenge5x5:
            "挑战 5x5"
        }
    }

    var shortLabel: String {
        switch self {
        case .easy3x3:
            "3x3"
        case .focus4x4:
            "4x4"
        case .challenge5x5:
            "5x5"
        }
    }

    var description: String {
        switch self {
        case .easy3x3:
            "适合热身，帮助快速进入专注状态。"
        case .focus4x4:
            "平衡速度与准确度，适合日常训练。"
        case .challenge5x5:
            "更高密度，更考验视觉搜索与节奏。"
        }
    }

    var gridSize: Int {
        switch self {
        case .easy3x3:
            3
        case .focus4x4:
            4
        case .challenge5x5:
            5
        }
    }

    var totalTiles: Int {
        gridSize * gridSize
    }
}

enum SchulteSessionStartMode: String, Codable {
    case manual
}

struct SchulteSessionConfig: Codable, Equatable {
    var difficulty: SchulteDifficulty
    var showHints: Bool
    var startMode: SchulteSessionStartMode
}

struct SchulteSessionResult: Identifiable, Codable, Equatable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    var duration: TimeInterval
    var difficulty: SchulteDifficulty
    var mistakeCount: Int

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        duration: TimeInterval,
        difficulty: SchulteDifficulty,
        mistakeCount: Int
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = duration
        self.difficulty = difficulty
        self.mistakeCount = mistakeCount
    }
}

struct TrainingSettings: Codable, Equatable {
    var showHints: Bool
    var enableSoundFeedback: Bool
    var preferredDifficulty: SchulteDifficulty

    static let `default` = TrainingSettings(
        showHints: true,
        enableSoundFeedback: false,
        preferredDifficulty: .focus4x4
    )
}

struct TrainingStatistics {
    let totalSessions: Int
    let bestTime: TimeInterval?
    let latestTime: TimeInterval?
    let recentAverage: TimeInterval?
    let mostPlayedDifficulty: SchulteDifficulty?
    let recentTrend: [TrendPoint]
    let recentImprovement: TimeInterval?

    init(results: [SchulteSessionResult]) {
        totalSessions = results.count
        bestTime = results.map(\.duration).min()
        latestTime = results.first?.duration
        recentAverage = results.isEmpty ? nil : results.prefix(5).map(\.duration).average

        let grouped = Dictionary(grouping: results, by: \.difficulty)
        mostPlayedDifficulty = grouped.max(by: { $0.value.count < $1.value.count })?.key
        recentTrend = Array(results.prefix(7).reversed()).enumerated().map { index, result in
            TrendPoint(index: index + 1, duration: result.duration, difficulty: result.difficulty)
        }

        if results.count > 1 {
            let baseline = Array(results.dropFirst().prefix(5)).map(\.duration).average
            if let baseline, let latest = results.first?.duration {
                recentImprovement = latest - baseline
            } else {
                recentImprovement = nil
            }
        } else {
            recentImprovement = nil
        }
    }
}

struct TrendPoint: Identifiable {
    let index: Int
    let duration: TimeInterval
    let difficulty: SchulteDifficulty

    var id: Int { index }
}

struct CompletedSessionSummary {
    let result: SchulteSessionResult
    let didSetPersonalBest: Bool
    let recentAverage: TimeInterval?
    let trendDelta: TimeInterval?

    init(result: SchulteSessionResult, historyAfterSave: [SchulteSessionResult]) {
        self.result = result
        let best = historyAfterSave.map(\.duration).min()
        didSetPersonalBest = best.map { result.duration <= $0 } ?? true

        let comparableResults = Array(historyAfterSave.dropFirst().prefix(5)).map(\.duration)
        recentAverage = comparableResults.isEmpty ? nil : comparableResults.average
        trendDelta = recentAverage.map { result.duration - $0 }
    }
}

extension Array where Element == TimeInterval {
    var average: TimeInterval? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}
