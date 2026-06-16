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
    case mainIdea(MainIdeaMetrics)
    case evidenceMap(EvidenceMapMetrics)
    case delayedRecall(DelayedRecallMetrics)
    case schulte(SchulteMetrics)
    case nBack(NBackMetrics)
    case digitSpan(DigitSpanMetrics)
    case changeDetection(ChangeDetectionMetrics)
    case corsiBlock(CorsiBlockMetrics)
    case syllogism(SyllogismMetrics)
    case logicArgument(LogicArgumentMetrics)
    case questionBank(BankPracticeMetrics)
    case devilGame(DevilGameMetrics)
}

struct MainIdeaMetrics: Codable, Equatable {
    var passageID: String
    var difficulty: Int
    var isCorrect: Bool
    var selectedIndex: Int
    var generatedSummary: String
    var matchedKeywordCount: Int
    var totalKeywordCount: Int
    var readingDuration: TimeInterval
    var responseDuration: TimeInterval

    var keywordCoverage: Double {
        guard totalKeywordCount > 0 else { return 0 }
        return Double(matchedKeywordCount) / Double(totalKeywordCount)
    }

    init(
        passageID: String,
        difficulty: Int,
        isCorrect: Bool,
        selectedIndex: Int,
        generatedSummary: String = "",
        matchedKeywordCount: Int = 0,
        totalKeywordCount: Int = 0,
        readingDuration: TimeInterval,
        responseDuration: TimeInterval
    ) {
        self.passageID = passageID
        self.difficulty = difficulty
        self.isCorrect = isCorrect
        self.selectedIndex = selectedIndex
        self.generatedSummary = generatedSummary
        self.matchedKeywordCount = matchedKeywordCount
        self.totalKeywordCount = totalKeywordCount
        self.readingDuration = readingDuration
        self.responseDuration = responseDuration
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        passageID = try c.decode(String.self, forKey: .passageID)
        difficulty = try c.decode(Int.self, forKey: .difficulty)
        isCorrect = try c.decode(Bool.self, forKey: .isCorrect)
        selectedIndex = try c.decode(Int.self, forKey: .selectedIndex)
        generatedSummary = try c.decodeIfPresent(String.self, forKey: .generatedSummary) ?? ""
        matchedKeywordCount = try c.decodeIfPresent(Int.self, forKey: .matchedKeywordCount) ?? 0
        totalKeywordCount = try c.decodeIfPresent(Int.self, forKey: .totalKeywordCount) ?? 0
        readingDuration = try c.decode(TimeInterval.self, forKey: .readingDuration)
        responseDuration = try c.decode(TimeInterval.self, forKey: .responseDuration)
    }
}

struct EvidenceMapMetrics: Codable, Equatable {
    var passageID: String
    var difficulty: Int
    var totalItems: Int
    var correctItems: Int
    var falseSelections: Int
    var accuracy: Double
    var mappedItems: Int
    var correctMappings: Int
    var mappingAccuracy: Double
    var responseDuration: TimeInterval

    init(
        passageID: String,
        difficulty: Int,
        totalItems: Int,
        correctItems: Int,
        falseSelections: Int,
        accuracy: Double,
        mappedItems: Int = 0,
        correctMappings: Int = 0,
        mappingAccuracy: Double = 0,
        responseDuration: TimeInterval
    ) {
        self.passageID = passageID
        self.difficulty = difficulty
        self.totalItems = totalItems
        self.correctItems = correctItems
        self.falseSelections = falseSelections
        self.accuracy = accuracy
        self.mappedItems = mappedItems
        self.correctMappings = correctMappings
        self.mappingAccuracy = mappingAccuracy
        self.responseDuration = responseDuration
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        passageID = try c.decode(String.self, forKey: .passageID)
        difficulty = try c.decode(Int.self, forKey: .difficulty)
        totalItems = try c.decode(Int.self, forKey: .totalItems)
        correctItems = try c.decode(Int.self, forKey: .correctItems)
        falseSelections = try c.decode(Int.self, forKey: .falseSelections)
        accuracy = try c.decode(Double.self, forKey: .accuracy)
        mappedItems = try c.decodeIfPresent(Int.self, forKey: .mappedItems) ?? 0
        correctMappings = try c.decodeIfPresent(Int.self, forKey: .correctMappings) ?? 0
        mappingAccuracy = try c.decodeIfPresent(Double.self, forKey: .mappingAccuracy) ?? 0
        responseDuration = try c.decode(TimeInterval.self, forKey: .responseDuration)
    }
}

struct DelayedRecallMetrics: Codable, Equatable {
    var passageID: String
    var difficulty: Int
    var delaySeconds: Int
    var totalTargets: Int
    var recalledTargets: Int
    var intrusionCount: Int
    var accuracy: Double
    var freeRecallText: String
    var freeRecallKeywordHits: Int
    var freeRecallKeywordTotal: Int
    var distractorQuestionCount: Int
    var distractorCorrectCount: Int
    var responseDuration: TimeInterval

    var freeRecallCoverage: Double {
        guard freeRecallKeywordTotal > 0 else { return 0 }
        return Double(freeRecallKeywordHits) / Double(freeRecallKeywordTotal)
    }

    init(
        passageID: String,
        difficulty: Int,
        delaySeconds: Int,
        totalTargets: Int,
        recalledTargets: Int,
        intrusionCount: Int,
        accuracy: Double,
        freeRecallText: String = "",
        freeRecallKeywordHits: Int = 0,
        freeRecallKeywordTotal: Int = 0,
        distractorQuestionCount: Int = 0,
        distractorCorrectCount: Int = 0,
        responseDuration: TimeInterval
    ) {
        self.passageID = passageID
        self.difficulty = difficulty
        self.delaySeconds = delaySeconds
        self.totalTargets = totalTargets
        self.recalledTargets = recalledTargets
        self.intrusionCount = intrusionCount
        self.accuracy = accuracy
        self.freeRecallText = freeRecallText
        self.freeRecallKeywordHits = freeRecallKeywordHits
        self.freeRecallKeywordTotal = freeRecallKeywordTotal
        self.distractorQuestionCount = distractorQuestionCount
        self.distractorCorrectCount = distractorCorrectCount
        self.responseDuration = responseDuration
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        passageID = try c.decode(String.self, forKey: .passageID)
        difficulty = try c.decode(Int.self, forKey: .difficulty)
        delaySeconds = try c.decode(Int.self, forKey: .delaySeconds)
        totalTargets = try c.decode(Int.self, forKey: .totalTargets)
        recalledTargets = try c.decode(Int.self, forKey: .recalledTargets)
        intrusionCount = try c.decode(Int.self, forKey: .intrusionCount)
        accuracy = try c.decode(Double.self, forKey: .accuracy)
        freeRecallText = try c.decodeIfPresent(String.self, forKey: .freeRecallText) ?? ""
        freeRecallKeywordHits = try c.decodeIfPresent(Int.self, forKey: .freeRecallKeywordHits) ?? 0
        freeRecallKeywordTotal = try c.decodeIfPresent(Int.self, forKey: .freeRecallKeywordTotal) ?? 0
        distractorQuestionCount = try c.decodeIfPresent(Int.self, forKey: .distractorQuestionCount) ?? 0
        distractorCorrectCount = try c.decodeIfPresent(Int.self, forKey: .distractorCorrectCount) ?? 0
        responseDuration = try c.decode(TimeInterval.self, forKey: .responseDuration)
    }
}

struct CorsiBlockMetrics: Codable, Equatable {
    var maxSpan: Int
    /// 阶梯法阈值估计：反转点均值，核心科学指标（峰值仅作参考）。
    var thresholdSpan: Double
    var reversalCount: Int
    var totalTrials: Int
    var correctTrials: Int
    var accuracy: Double
    var positionErrors: Int
    var mode: CorsiBlockMode
}

extension CorsiBlockMetrics {
    // 自定义解码，兼容旧存档（无 thresholdSpan / reversalCount 字段）。
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        maxSpan = try c.decode(Int.self, forKey: .maxSpan)
        thresholdSpan = try c.decodeIfPresent(Double.self, forKey: .thresholdSpan) ?? Double(maxSpan)
        reversalCount = try c.decodeIfPresent(Int.self, forKey: .reversalCount) ?? 0
        totalTrials = try c.decode(Int.self, forKey: .totalTrials)
        correctTrials = try c.decode(Int.self, forKey: .correctTrials)
        accuracy = try c.decode(Double.self, forKey: .accuracy)
        positionErrors = try c.decode(Int.self, forKey: .positionErrors)
        mode = try c.decode(CorsiBlockMode.self, forKey: .mode)
    }
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

struct NBackMetrics: Codable, Equatable {
    var nLevel: Int
    var totalTrials: Int
    var hitRate: Double
    var falseAlarmRate: Double
    var dPrime: Double
    var averageDecisionInterval: TimeInterval

    init(
        nLevel: Int,
        totalTrials: Int,
        hitRate: Double,
        falseAlarmRate: Double,
        dPrime: Double,
        averageDecisionInterval: TimeInterval = 0
    ) {
        self.nLevel = nLevel
        self.totalTrials = totalTrials
        self.hitRate = hitRate
        self.falseAlarmRate = falseAlarmRate
        self.dPrime = dPrime
        self.averageDecisionInterval = averageDecisionInterval
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nLevel = try c.decode(Int.self, forKey: .nLevel)
        totalTrials = try c.decode(Int.self, forKey: .totalTrials)
        hitRate = try c.decode(Double.self, forKey: .hitRate)
        falseAlarmRate = try c.decode(Double.self, forKey: .falseAlarmRate)
        dPrime = try c.decode(Double.self, forKey: .dPrime)
        averageDecisionInterval = try c.decodeIfPresent(TimeInterval.self, forKey: .averageDecisionInterval) ?? 0
    }
}

struct DigitSpanMetrics: Codable, Equatable {
    var maxSpanForward: Int
    var maxSpanBackward: Int
    /// 阶梯法阈值估计：反转点均值，核心科学指标（峰值仅作参考）。
    var thresholdSpan: Double
    var reversalCount: Int
    var totalTrials: Int
    var correctTrials: Int
    var accuracy: Double
    var positionErrors: Int
}

extension DigitSpanMetrics {
    // 自定义解码，兼容旧存档（无 thresholdSpan / reversalCount 字段）。
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        maxSpanForward = try c.decode(Int.self, forKey: .maxSpanForward)
        maxSpanBackward = try c.decode(Int.self, forKey: .maxSpanBackward)
        thresholdSpan = try c.decodeIfPresent(Double.self, forKey: .thresholdSpan)
            ?? Double(max(maxSpanForward, maxSpanBackward))
        reversalCount = try c.decodeIfPresent(Int.self, forKey: .reversalCount) ?? 0
        totalTrials = try c.decode(Int.self, forKey: .totalTrials)
        correctTrials = try c.decode(Int.self, forKey: .correctTrials)
        accuracy = try c.decode(Double.self, forKey: .accuracy)
        positionErrors = try c.decode(Int.self, forKey: .positionErrors)
    }
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

    var mainIdeaMetrics: MainIdeaMetrics? {
        if case let .mainIdea(m) = metrics { return m }
        return nil
    }

    var evidenceMapMetrics: EvidenceMapMetrics? {
        if case let .evidenceMap(m) = metrics { return m }
        return nil
    }

    var delayedRecallMetrics: DelayedRecallMetrics? {
        if case let .delayedRecall(m) = metrics { return m }
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

    var changeDetectionMetrics: ChangeDetectionMetrics? {
        if case let .changeDetection(m) = metrics { return m }
        return nil
    }

    var corsiBlockMetrics: CorsiBlockMetrics? {
        if case let .corsiBlock(m) = metrics { return m }
        return nil
    }

    var syllogismMetrics: SyllogismMetrics? {
        if case let .syllogism(m) = metrics { return m }
        return nil
    }

    var logicArgumentMetrics: LogicArgumentMetrics? {
        if case let .logicArgument(m) = metrics { return m }
        return nil
    }

    var questionBankMetrics: BankPracticeMetrics? {
        if case let .questionBank(m) = metrics { return m }
        return nil
    }

    var devilGameMetrics: DevilGameMetrics? {
        if case let .devilGame(m) = metrics { return m }
        return nil
    }
}
