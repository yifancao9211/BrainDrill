import Foundation

enum SchulteDifficulty: String, CaseIterable, Codable, Identifiable {
    case easy3x3
    case focus4x4
    case challenge5x5
    case expert6x6
    case master7x7
    case elite8x8
    case legend9x9

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy3x3:      "热身 3×3"
        case .focus4x4:     "经典 4×4"
        case .challenge5x5: "挑战 5×5"
        case .expert6x6:    "专家 6×6"
        case .master7x7:    "大师 7×7"
        case .elite8x8:     "精英 8×8"
        case .legend9x9:    "传奇 9×9"
        }
    }

    var shortLabel: String {
        switch self {
        case .easy3x3:      "3×3"
        case .focus4x4:     "4×4"
        case .challenge5x5: "5×5"
        case .expert6x6:    "6×6"
        case .master7x7:    "7×7"
        case .elite8x8:     "8×8"
        case .legend9x9:    "9×9"
        }
    }

    var description: String {
        switch self {
        case .easy3x3:      "适合热身，帮助快速进入专注状态。"
        case .focus4x4:     "平衡速度与准确度，适合日常训练。"
        case .challenge5x5: "标准难度 + 色块干扰，训练抗干扰。"
        case .expert6x6:    "36 格 + 色块干扰，考验周边视觉。"
        case .master7x7:    "49 格 + 强色块干扰，极限专注。"
        case .elite8x8:     "64 格高密度，需要强大的视野广度。"
        case .legend9x9:    "81 格终极挑战，视觉搜索巅峰。"
        }
    }

    var gridSize: Int {
        switch self {
        case .easy3x3:      3
        case .focus4x4:     4
        case .challenge5x5: 5
        case .expert6x6:    6
        case .master7x7:    7
        case .elite8x8:     8
        case .legend9x9:    9
        }
    }

    var totalTiles: Int { gridSize * gridSize }

    var hasColorDistraction: Bool {
        switch self {
        case .easy3x3, .focus4x4: false
        default: true
        }
    }

    var distractionIntensity: Double {
        switch self {
        case .easy3x3, .focus4x4: 0
        case .challenge5x5: 0.15
        case .expert6x6:    0.25
        case .master7x7:    0.35
        case .elite8x8:     0.40
        case .legend9x9:    0.45
        }
    }

    var harder: SchulteDifficulty? {
        switch self {
        case .easy3x3:      .focus4x4
        case .focus4x4:     .challenge5x5
        case .challenge5x5: .expert6x6
        case .expert6x6:    .master7x7
        case .master7x7:    .elite8x8
        case .elite8x8:     .legend9x9
        case .legend9x9:    nil
        }
    }

    var easier: SchulteDifficulty? {
        switch self {
        case .easy3x3:      nil
        case .focus4x4:     .easy3x3
        case .challenge5x5: .focus4x4
        case .expert6x6:    .challenge5x5
        case .master7x7:    .expert6x6
        case .elite8x8:     .master7x7
        case .legend9x9:    .elite8x8
        }
    }
}

enum SchulteSessionStartMode: String, Codable {
    case manual
}

struct SchulteSessionConfig: Codable, Equatable {
    var difficulty: SchulteDifficulty
    var showHints: Bool
    var startMode: SchulteSessionStartMode
    var showFixationDot: Bool = true
}

struct SchulteSessionResult: Identifiable, Codable, Equatable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    var duration: TimeInterval
    var difficulty: SchulteDifficulty
    var mistakeCount: Int
    var perNumberDurations: [TimeInterval]

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        duration: TimeInterval,
        difficulty: SchulteDifficulty,
        mistakeCount: Int,
        perNumberDurations: [TimeInterval] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = duration
        self.difficulty = difficulty
        self.mistakeCount = mistakeCount
        self.perNumberDurations = perNumberDurations
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        endedAt = try c.decode(Date.self, forKey: .endedAt)
        duration = try c.decode(TimeInterval.self, forKey: .duration)
        difficulty = try c.decode(SchulteDifficulty.self, forKey: .difficulty)
        mistakeCount = try c.decode(Int.self, forKey: .mistakeCount)
        perNumberDurations = try c.decodeIfPresent([TimeInterval].self, forKey: .perNumberDurations) ?? []
    }

    func toSessionResult(setIndex: Int = 0, repIndex: Int = 0) -> SessionResult {
        SessionResult(
            id: id,
            module: .schulte,
            startedAt: startedAt,
            endedAt: endedAt,
            duration: duration,
            metrics: .schulte(SchulteMetrics(
                difficulty: difficulty,
                mistakeCount: mistakeCount,
                setIndex: setIndex,
                repIndex: repIndex,
                perNumberDurations: perNumberDurations
            ))
        )
    }
}

struct SchulteSetRepConfig: Codable, Equatable {
    var setsPerSession: Int = 3
    var repsPerSet: Int = 3
    var restBetweenRepsSec: Int = 5
    var restBetweenSetsSec: Int = 30
}

struct CompletedSchulteSummary: Equatable {
    let result: SchulteSessionResult
    let didSetPersonalBest: Bool
    let recentAverage: TimeInterval?
    let trendDelta: TimeInterval?
    let difficultyEvaluation: AdaptiveDifficulty.Evaluation?
    let setIndex: Int
    let repIndex: Int

    init(
        result: SchulteSessionResult,
        schulteHistory: [SessionResult],
        adaptiveEnabled: Bool = false,
        adaptiveConfig: AdaptiveDifficulty.Config = .init(),
        setIndex: Int = 0,
        repIndex: Int = 0
    ) {
        self.result = result
        self.setIndex = setIndex
        self.repIndex = repIndex

        let allDurations = schulteHistory.map(\.duration)
        let best = allDurations.min()
        didSetPersonalBest = best.map { result.duration <= $0 } ?? true

        let comparableResults = Array(allDurations.dropFirst().prefix(5))
        recentAverage = comparableResults.isEmpty ? nil : comparableResults.average
        trendDelta = recentAverage.map { result.duration - $0 }

        if adaptiveEnabled {
            let legacyResults = schulteHistory.compactMap { session -> SchulteSessionResult? in
                guard let m = session.schulteMetrics else { return nil }
                return SchulteSessionResult(
                    id: session.id, startedAt: session.startedAt, endedAt: session.endedAt,
                    duration: session.duration, difficulty: m.difficulty, mistakeCount: m.mistakeCount
                )
            }
            difficultyEvaluation = AdaptiveDifficulty.evaluate(
                currentDifficulty: result.difficulty,
                history: legacyResults,
                config: adaptiveConfig
            )
        } else {
            difficultyEvaluation = nil
        }
    }
}

extension Array where Element == TimeInterval {
    var average: TimeInterval? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}
