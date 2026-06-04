import Foundation

struct TrainingSettings: Codable, Equatable {
    // Schulte
    var showHints: Bool
    var preferredDifficulty: SchulteDifficulty
    var adaptiveDifficultyEnabled: Bool
    var adaptiveConfig: AdaptiveDifficulty.Config
    var schulteSetRep: SchulteSetRepConfig
    var showFixationDot: Bool

    // N-Back
    var nBackStartingN: Int
    var nBackStimulusDurationMs: Int
    var nBackISIMs: Int

    // Digit Span
    var digitSpanStartingLength: Int
    var digitSpanPresentationMs: Int

    // Corsi Block
    var corsiBlockStartingLength: Int

    // Change Detection
    var changeDetectionInitialSetSize: Int
    var changeDetectionEncodingMs: Int
    var changeDetectionRetentionMs: Int

    // General
    var dailyPlanEnabled: Bool

    init() {
        self.showHints = true
        self.preferredDifficulty = .focus4x4
        self.adaptiveDifficultyEnabled = true
        self.adaptiveConfig = .init()
        self.schulteSetRep = .init()
        self.showFixationDot = true
        self.nBackStartingN = 1
        self.nBackStimulusDurationMs = 800
        self.nBackISIMs = 1400
        self.digitSpanStartingLength = 3
        self.digitSpanPresentationMs = 800
        self.corsiBlockStartingLength = 3
        self.changeDetectionInitialSetSize = 3
        self.changeDetectionEncodingMs = 350
        self.changeDetectionRetentionMs = 600
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
        nBackStartingN = try c.decodeIfPresent(Int.self, forKey: .nBackStartingN) ?? 1
        nBackStimulusDurationMs = try c.decodeIfPresent(Int.self, forKey: .nBackStimulusDurationMs) ?? 800
        nBackISIMs = try c.decodeIfPresent(Int.self, forKey: .nBackISIMs) ?? 1400
        digitSpanStartingLength = try c.decodeIfPresent(Int.self, forKey: .digitSpanStartingLength) ?? 3
        digitSpanPresentationMs = try c.decodeIfPresent(Int.self, forKey: .digitSpanPresentationMs) ?? 800
        corsiBlockStartingLength = try c.decodeIfPresent(Int.self, forKey: .corsiBlockStartingLength) ?? 3
        changeDetectionInitialSetSize = try c.decodeIfPresent(Int.self, forKey: .changeDetectionInitialSetSize) ?? 3
        changeDetectionEncodingMs = try c.decodeIfPresent(Int.self, forKey: .changeDetectionEncodingMs) ?? 350
        changeDetectionRetentionMs = try c.decodeIfPresent(Int.self, forKey: .changeDetectionRetentionMs) ?? 600
        dailyPlanEnabled = try c.decodeIfPresent(Bool.self, forKey: .dailyPlanEnabled) ?? true
    }

    static let `default` = TrainingSettings()

    func normalizedForCurrentDefaults() -> TrainingSettings {
        var normalized = self
        if normalized.schulteSetRep == .legacyDefault || normalized.schulteSetRep == .previousShortDefault {
            normalized.schulteSetRep = .init()
        }
        return normalized
    }
}
