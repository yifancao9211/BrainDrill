import Foundation

struct SessionConditions: Codable, Equatable {
    var hintsEnabled: Bool
    var feedbackEnabled: Bool
    var adaptiveEnabled: Bool
    var customParameters: [String: String]

    init(
        hintsEnabled: Bool = false,
        feedbackEnabled: Bool = true,
        adaptiveEnabled: Bool = false,
        customParameters: [String: String] = [:]
    ) {
        self.hintsEnabled = hintsEnabled
        self.feedbackEnabled = feedbackEnabled
        self.adaptiveEnabled = adaptiveEnabled
        self.customParameters = customParameters
    }
}

struct SessionResult: Identifiable, Codable, Equatable {
    var id: UUID
    var module: TrainingModule
    var startedAt: Date
    var endedAt: Date
    var duration: TimeInterval
    var metrics: ModuleMetrics
    var conditions: SessionConditions

    init(
        id: UUID = UUID(),
        module: TrainingModule,
        startedAt: Date,
        endedAt: Date,
        duration: TimeInterval,
        metrics: ModuleMetrics,
        conditions: SessionConditions = SessionConditions()
    ) {
        self.id = id
        self.module = module
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = duration
        self.metrics = metrics
        self.conditions = conditions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        module = try c.decode(TrainingModule.self, forKey: .module)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        endedAt = try c.decode(Date.self, forKey: .endedAt)
        duration = try c.decode(TimeInterval.self, forKey: .duration)
        metrics = try c.decode(ModuleMetrics.self, forKey: .metrics)
        conditions = try c.decodeIfPresent(SessionConditions.self, forKey: .conditions) ?? SessionConditions()
    }
}

enum ModuleMetrics: Codable, Equatable {
    case schulte(SchulteMetrics)
    case flanker(FlankerMetrics)
    case goNoGo(GoNoGoMetrics)
    case nBack(NBackMetrics)
    case digitSpan(DigitSpanMetrics)
    case choiceRT(ChoiceRTMetrics)
    case changeDetection(ChangeDetectionMetrics)
    case visualSearch(VisualSearchMetrics)
}

struct SchulteMetrics: Codable, Equatable {
    var difficulty: SchulteDifficulty
    var mistakeCount: Int
    var setIndex: Int
    var repIndex: Int
    var perNumberDurations: [TimeInterval]

    init(difficulty: SchulteDifficulty, mistakeCount: Int, setIndex: Int, repIndex: Int, perNumberDurations: [TimeInterval] = []) {
        self.difficulty = difficulty
        self.mistakeCount = mistakeCount
        self.setIndex = setIndex
        self.repIndex = repIndex
        self.perNumberDurations = perNumberDurations
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        difficulty = try c.decode(SchulteDifficulty.self, forKey: .difficulty)
        mistakeCount = try c.decode(Int.self, forKey: .mistakeCount)
        setIndex = try c.decode(Int.self, forKey: .setIndex)
        repIndex = try c.decode(Int.self, forKey: .repIndex)
        perNumberDurations = try c.decodeIfPresent([TimeInterval].self, forKey: .perNumberDurations) ?? []
    }
}

struct FlankerMetrics: Codable, Equatable {
    var totalTrials: Int
    var congruentRT: TimeInterval
    var incongruentRT: TimeInterval
    var conflictCost: TimeInterval
    var accuracy: Double
    var stimulusDurationMs: Int
}

struct GoNoGoMetrics: Codable, Equatable {
    var totalTrials: Int
    var goRT: TimeInterval
    var goAccuracy: Double
    var noGoAccuracy: Double
    var dPrime: Double
}

struct NBackMetrics: Codable, Equatable {
    var nLevel: Int
    var totalTrials: Int
    var hitRate: Double
    var falseAlarmRate: Double
    var dPrime: Double
}

struct DigitSpanMetrics: Codable, Equatable {
    var maxSpanForward: Int
    var maxSpanBackward: Int
    var totalTrials: Int
    var correctTrials: Int
    var accuracy: Double
    var positionErrors: Int
}

struct ChoiceRTMetrics: Codable, Equatable {
    var totalTrials: Int
    var medianRT: TimeInterval
    var rtStandardDeviation: TimeInterval
    var accuracy: Double
    var postErrorSlowing: TimeInterval
    var anticipationCount: Int
    var choiceCount: Int
}

struct ChangeDetectionMetrics: Codable, Equatable {
    var totalTrials: Int
    var accuracy: Double
    var dPrime: Double
    var hitRate: Double
    var falseAlarmRate: Double
    var maxSetSize: Int
    var averageRT: TimeInterval
}

struct VisualSearchMetrics: Codable, Equatable {
    var totalTrials: Int
    var accuracy: Double
    var searchSlope: TimeInterval
    var presentRT: TimeInterval
    var absentRT: TimeInterval
    var setSizeRTs: [Int: TimeInterval]
    var errorRate: Double
}

extension SessionResult {
    static func fromLegacy(_ legacy: SchulteSessionResult) -> SessionResult {
        SessionResult(
            id: legacy.id,
            module: .schulte,
            startedAt: legacy.startedAt,
            endedAt: legacy.endedAt,
            duration: legacy.duration,
            metrics: .schulte(SchulteMetrics(
                difficulty: legacy.difficulty,
                mistakeCount: legacy.mistakeCount,
                setIndex: 0,
                repIndex: 0
            ))
        )
    }

    var schulteMetrics: SchulteMetrics? {
        if case let .schulte(m) = metrics { return m }
        return nil
    }

    var flankerMetrics: FlankerMetrics? {
        if case let .flanker(m) = metrics { return m }
        return nil
    }

    var goNoGoMetrics: GoNoGoMetrics? {
        if case let .goNoGo(m) = metrics { return m }
        return nil
    }

    var nBackMetrics: NBackMetrics? {
        if case let .nBack(m) = metrics { return m }
        return nil
    }

    var digitSpanMetrics: DigitSpanMetrics? {
        if case let .digitSpan(m) = metrics { return m }
        return nil
    }

    var choiceRTMetrics: ChoiceRTMetrics? {
        if case let .choiceRT(m) = metrics { return m }
        return nil
    }

    var changeDetectionMetrics: ChangeDetectionMetrics? {
        if case let .changeDetection(m) = metrics { return m }
        return nil
    }

    var visualSearchMetrics: VisualSearchMetrics? {
        if case let .visualSearch(m) = metrics { return m }
        return nil
    }
}
