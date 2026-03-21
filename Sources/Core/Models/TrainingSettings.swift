import Foundation

struct TrainingSettings: Codable, Equatable {
    // Schulte
    var showHints: Bool
    var enableSoundFeedback: Bool
    var preferredDifficulty: SchulteDifficulty
    var adaptiveDifficultyEnabled: Bool
    var adaptiveConfig: AdaptiveDifficulty.Config
    var schulteSetRep: SchulteSetRepConfig
    var showFixationDot: Bool

    // Flanker
    var flankerStimulusDurationMs: Int

    // N-Back
    var nBackStartingN: Int

    // Digit Span
    var digitSpanStartingLength: Int
    var digitSpanPresentationMs: Int

    // Choice RT
    var choiceRTChoiceCount: Int
    var choiceRTTrialsPerBlock: Int

    // Change Detection
    var changeDetectionInitialSetSize: Int
    var changeDetectionEncodingMs: Int
    var changeDetectionRetentionMs: Int

    // Visual Search
    var visualSearchSetSizes: [Int]
    var visualSearchTrialsPerSize: Int

    // AI
    var aiBaseURL: String
    var aiAPIKey: String

    // General
    var dailyPlanEnabled: Bool

    init(
        showHints: Bool,
        enableSoundFeedback: Bool,
        preferredDifficulty: SchulteDifficulty,
        adaptiveDifficultyEnabled: Bool,
        adaptiveConfig: AdaptiveDifficulty.Config,
        schulteSetRep: SchulteSetRepConfig,
        showFixationDot: Bool,
        flankerStimulusDurationMs: Int,
        nBackStartingN: Int,
        digitSpanStartingLength: Int,
        digitSpanPresentationMs: Int,
        choiceRTChoiceCount: Int,
        choiceRTTrialsPerBlock: Int,
        changeDetectionInitialSetSize: Int,
        changeDetectionEncodingMs: Int,
        changeDetectionRetentionMs: Int,
        visualSearchSetSizes: [Int],
        visualSearchTrialsPerSize: Int,
        aiBaseURL: String = "https://litellm.qa.domio.so",
        aiAPIKey: String = "sk-3AXEzLuCihLJH9gDIXV6Lw",
        dailyPlanEnabled: Bool
    ) {
        self.showHints = showHints
        self.enableSoundFeedback = enableSoundFeedback
        self.preferredDifficulty = preferredDifficulty
        self.adaptiveDifficultyEnabled = adaptiveDifficultyEnabled
        self.adaptiveConfig = adaptiveConfig
        self.schulteSetRep = schulteSetRep
        self.showFixationDot = showFixationDot
        self.flankerStimulusDurationMs = flankerStimulusDurationMs
        self.nBackStartingN = nBackStartingN
        self.digitSpanStartingLength = digitSpanStartingLength
        self.digitSpanPresentationMs = digitSpanPresentationMs
        self.choiceRTChoiceCount = choiceRTChoiceCount
        self.choiceRTTrialsPerBlock = choiceRTTrialsPerBlock
        self.changeDetectionInitialSetSize = changeDetectionInitialSetSize
        self.changeDetectionEncodingMs = changeDetectionEncodingMs
        self.changeDetectionRetentionMs = changeDetectionRetentionMs
        self.visualSearchSetSizes = visualSearchSetSizes
        self.visualSearchTrialsPerSize = visualSearchTrialsPerSize
        self.aiBaseURL = aiBaseURL
        self.aiAPIKey = aiAPIKey
        self.dailyPlanEnabled = dailyPlanEnabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        showHints = try c.decodeIfPresent(Bool.self, forKey: .showHints) ?? true
        enableSoundFeedback = try c.decodeIfPresent(Bool.self, forKey: .enableSoundFeedback) ?? false
        preferredDifficulty = try c.decodeIfPresent(SchulteDifficulty.self, forKey: .preferredDifficulty) ?? .focus4x4
        adaptiveDifficultyEnabled = try c.decodeIfPresent(Bool.self, forKey: .adaptiveDifficultyEnabled) ?? true
        adaptiveConfig = try c.decodeIfPresent(AdaptiveDifficulty.Config.self, forKey: .adaptiveConfig) ?? .init()
        schulteSetRep = try c.decodeIfPresent(SchulteSetRepConfig.self, forKey: .schulteSetRep) ?? .init()
        showFixationDot = try c.decodeIfPresent(Bool.self, forKey: .showFixationDot) ?? true
        flankerStimulusDurationMs = try c.decodeIfPresent(Int.self, forKey: .flankerStimulusDurationMs) ?? 200
        nBackStartingN = try c.decodeIfPresent(Int.self, forKey: .nBackStartingN) ?? 1
        digitSpanStartingLength = try c.decodeIfPresent(Int.self, forKey: .digitSpanStartingLength) ?? 3
        digitSpanPresentationMs = try c.decodeIfPresent(Int.self, forKey: .digitSpanPresentationMs) ?? 1000
        choiceRTChoiceCount = try c.decodeIfPresent(Int.self, forKey: .choiceRTChoiceCount) ?? 2
        choiceRTTrialsPerBlock = try c.decodeIfPresent(Int.self, forKey: .choiceRTTrialsPerBlock) ?? 30
        changeDetectionInitialSetSize = try c.decodeIfPresent(Int.self, forKey: .changeDetectionInitialSetSize) ?? 3
        changeDetectionEncodingMs = try c.decodeIfPresent(Int.self, forKey: .changeDetectionEncodingMs) ?? 500
        changeDetectionRetentionMs = try c.decodeIfPresent(Int.self, forKey: .changeDetectionRetentionMs) ?? 900
        visualSearchSetSizes = try c.decodeIfPresent([Int].self, forKey: .visualSearchSetSizes) ?? [8, 16, 24]
        visualSearchTrialsPerSize = try c.decodeIfPresent(Int.self, forKey: .visualSearchTrialsPerSize) ?? 10
        aiBaseURL = try c.decodeIfPresent(String.self, forKey: .aiBaseURL) ?? "https://litellm.qa.domio.so"
        aiAPIKey = try c.decodeIfPresent(String.self, forKey: .aiAPIKey) ?? "sk-3AXEzLuCihLJH9gDIXV6Lw"
        dailyPlanEnabled = try c.decodeIfPresent(Bool.self, forKey: .dailyPlanEnabled) ?? true
    }

    static let `default` = TrainingSettings(
        showHints: true,
        enableSoundFeedback: false,
        preferredDifficulty: .focus4x4,
        adaptiveDifficultyEnabled: true,
        adaptiveConfig: .init(),
        schulteSetRep: .init(),
        showFixationDot: true,
        flankerStimulusDurationMs: 200,
        nBackStartingN: 1,
        digitSpanStartingLength: 3,
        digitSpanPresentationMs: 1000,
        choiceRTChoiceCount: 2,
        choiceRTTrialsPerBlock: 30,
        changeDetectionInitialSetSize: 3,
        changeDetectionEncodingMs: 500,
        changeDetectionRetentionMs: 900,
        visualSearchSetSizes: [8, 16, 24],
        visualSearchTrialsPerSize: 10,
        dailyPlanEnabled: true
    )
}
