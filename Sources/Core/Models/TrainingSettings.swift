import Foundation

struct TrainingSettings: Codable, Equatable {
    static let defaultAIBaseURL = "https://litellm.qa.domio.so"
    static let defaultAIModel = "claude-opus-4-6"
    static let legacyDefaultAIModel = "claude-sonnet-4-20250514"
    private static let keychainAPIKeyName = "ai_api_key"

    // Schulte
    var showHints: Bool
    var preferredDifficulty: SchulteDifficulty
    var adaptiveDifficultyEnabled: Bool
    var adaptiveConfig: AdaptiveDifficulty.Config
    var schulteSetRep: SchulteSetRepConfig
    var showFixationDot: Bool

    // Flanker
    var flankerStimulusDurationMs: Int

    // N-Back
    var nBackStartingN: Int
    var nBackStimulusDurationMs: Int
    var nBackISIMs: Int

    // Digit Span
    var digitSpanStartingLength: Int
    var digitSpanPresentationMs: Int

    // Corsi Block
    var corsiBlockStartingLength: Int

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
    var aiAPIKey: String {
        didSet {
            if !aiAPIKey.isEmpty {
                KeychainHelper.save(key: Self.keychainAPIKeyName, value: aiAPIKey)
            }
        }
    }
    var aiModel: String
    var materialsAutoSourceCountPerRun: Int
    var materialsCandidateThreshold: Double

    // General
    var dailyPlanEnabled: Bool

    init() {
        self.showHints = true
        self.preferredDifficulty = .focus4x4
        self.adaptiveDifficultyEnabled = true
        self.adaptiveConfig = .init()
        self.schulteSetRep = .init()
        self.showFixationDot = true
        self.flankerStimulusDurationMs = 200
        self.nBackStartingN = 1
        self.nBackStimulusDurationMs = 800
        self.nBackISIMs = 1400
        self.digitSpanStartingLength = 3
        self.digitSpanPresentationMs = 800
        self.corsiBlockStartingLength = 3
        self.choiceRTChoiceCount = 2
        self.choiceRTTrialsPerBlock = 18
        self.changeDetectionInitialSetSize = 3
        self.changeDetectionEncodingMs = 350
        self.changeDetectionRetentionMs = 600
        self.visualSearchSetSizes = [8, 16, 24]
        self.visualSearchTrialsPerSize = 6
        self.aiBaseURL = Self.defaultAIBaseURL
        self.aiAPIKey = KeychainHelper.load(key: Self.keychainAPIKeyName) ?? ""
        self.aiModel = Self.defaultAIModel
        self.materialsAutoSourceCountPerRun = 3
        self.materialsCandidateThreshold = 70
        self.dailyPlanEnabled = true
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        showHints = try c.decodeIfPresent(Bool.self, forKey: .showHints) ?? true
        preferredDifficulty = try c.decodeIfPresent(SchulteDifficulty.self, forKey: .preferredDifficulty) ?? .focus4x4
        adaptiveDifficultyEnabled = try c.decodeIfPresent(Bool.self, forKey: .adaptiveDifficultyEnabled) ?? true
        adaptiveConfig = try c.decodeIfPresent(AdaptiveDifficulty.Config.self, forKey: .adaptiveConfig) ?? .init()
        schulteSetRep = try c.decodeIfPresent(SchulteSetRepConfig.self, forKey: .schulteSetRep) ?? .init()
        showFixationDot = try c.decodeIfPresent(Bool.self, forKey: .showFixationDot) ?? true
        flankerStimulusDurationMs = try c.decodeIfPresent(Int.self, forKey: .flankerStimulusDurationMs) ?? 200
        nBackStartingN = try c.decodeIfPresent(Int.self, forKey: .nBackStartingN) ?? 1
        nBackStimulusDurationMs = try c.decodeIfPresent(Int.self, forKey: .nBackStimulusDurationMs) ?? 800
        nBackISIMs = try c.decodeIfPresent(Int.self, forKey: .nBackISIMs) ?? 1400
        digitSpanStartingLength = try c.decodeIfPresent(Int.self, forKey: .digitSpanStartingLength) ?? 3
        digitSpanPresentationMs = try c.decodeIfPresent(Int.self, forKey: .digitSpanPresentationMs) ?? 800
        corsiBlockStartingLength = try c.decodeIfPresent(Int.self, forKey: .corsiBlockStartingLength) ?? 3
        choiceRTChoiceCount = try c.decodeIfPresent(Int.self, forKey: .choiceRTChoiceCount) ?? 2
        choiceRTTrialsPerBlock = try c.decodeIfPresent(Int.self, forKey: .choiceRTTrialsPerBlock) ?? 18
        changeDetectionInitialSetSize = try c.decodeIfPresent(Int.self, forKey: .changeDetectionInitialSetSize) ?? 3
        changeDetectionEncodingMs = try c.decodeIfPresent(Int.self, forKey: .changeDetectionEncodingMs) ?? 350
        changeDetectionRetentionMs = try c.decodeIfPresent(Int.self, forKey: .changeDetectionRetentionMs) ?? 600
        visualSearchSetSizes = try c.decodeIfPresent([Int].self, forKey: .visualSearchSetSizes) ?? [8, 16, 24]
        visualSearchTrialsPerSize = try c.decodeIfPresent(Int.self, forKey: .visualSearchTrialsPerSize) ?? 6
        aiBaseURL = try c.decodeIfPresent(String.self, forKey: .aiBaseURL) ?? Self.defaultAIBaseURL
        // Migrate: if Keychain has a value, use it; otherwise try legacy JSON field and migrate
        let keychainValue = KeychainHelper.load(key: Self.keychainAPIKeyName)
        let legacyValue = try c.decodeIfPresent(String.self, forKey: .aiAPIKey)
        if let kv = keychainValue, !kv.isEmpty {
            aiAPIKey = kv
        } else if let lv = legacyValue, !lv.isEmpty {
            aiAPIKey = lv
            KeychainHelper.save(key: Self.keychainAPIKeyName, value: lv)
        } else {
            aiAPIKey = ""
        }
        aiModel = try c.decodeIfPresent(String.self, forKey: .aiModel) ?? Self.defaultAIModel
        materialsAutoSourceCountPerRun = try c.decodeIfPresent(Int.self, forKey: .materialsAutoSourceCountPerRun) ?? 3
        materialsCandidateThreshold = try c.decodeIfPresent(Double.self, forKey: .materialsCandidateThreshold) ?? 70
        dailyPlanEnabled = try c.decodeIfPresent(Bool.self, forKey: .dailyPlanEnabled) ?? true
    }

    static let `default` = TrainingSettings()

    func normalizedForCurrentDefaults() -> TrainingSettings {
        var normalized = self
        let trimmedModel = normalized.aiModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedModel.isEmpty || trimmedModel == Self.legacyDefaultAIModel {
            normalized.aiModel = Self.defaultAIModel
        }
        if normalized.aiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalized.aiBaseURL = Self.defaultAIBaseURL
        }
        return normalized
    }
}
