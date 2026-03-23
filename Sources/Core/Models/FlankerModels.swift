import Foundation

enum FlankerTrialType: String, Codable, Equatable {
    case congruent
    case incongruent
}

enum FlankerDirection: String, Codable, Equatable {
    case left
    case right
}

struct FlankerTrial: Identifiable, Equatable {
    let id: Int
    let type: FlankerTrialType
    let targetDirection: FlankerDirection
    let flankerDirection: FlankerDirection

    var arrows: String {
        let target = targetDirection == .left ? "←" : "→"
        let flanker = flankerDirection == .left ? "←" : "→"
        return "\(flanker) \(flanker) \(target) \(flanker) \(flanker)"
    }
}

struct FlankerTrialResult: Codable, Equatable {
    let trialIndex: Int
    let type: FlankerTrialType
    let responseCorrect: Bool
    let reactionTime: TimeInterval?
}

struct FlankerLevelSpec: Equatable {
    let level: Int
    let trialsPerBlock: Int
    let stimulusDurationMs: Int
    let responseWindowMs: Int
    let fixationDurationMs: Int
    let itiRangeMs: ClosedRange<Int>
    let incongruentRatio: Double
}

struct FlankerSessionConfig: Equatable {
    var blockCount: Int
    var startingLevel: Int?
    var manualTrialsPerBlock: Int?
    var manualStimulusDurationMs: Int?
    var manualResponseWindowMs: Int?
    var manualFixationDurationMs: Int?
    var manualITIRangeMs: ClosedRange<Int>?
    var manualIncongruentRatio: Double?

    init(
        trialsPerBlock: Int? = 24,
        blockCount: Int = 1,
        stimulusDurationMs: Int? = 200,
        responseWindowMs: Int? = 1500,
        fixationDurationMs: Int? = 500,
        itiRangeMs: ClosedRange<Int>? = 800...1200,
        incongruentRatio: Double? = 0.5,
        startingLevel: Int? = nil
    ) {
        self.blockCount = blockCount
        self.startingLevel = startingLevel
        self.manualTrialsPerBlock = trialsPerBlock
        self.manualStimulusDurationMs = stimulusDurationMs
        self.manualResponseWindowMs = responseWindowMs
        self.manualFixationDurationMs = fixationDurationMs
        self.manualITIRangeMs = itiRangeMs
        self.manualIncongruentRatio = incongruentRatio
    }

    var isAdaptive: Bool { startingLevel != nil }

    var initialSpec: FlankerLevelSpec {
        if let startingLevel {
            return spec(for: startingLevel)
        }
        return FlankerLevelSpec(
            level: 3,
            trialsPerBlock: manualTrialsPerBlock ?? 24,
            stimulusDurationMs: manualStimulusDurationMs ?? 200,
            responseWindowMs: manualResponseWindowMs ?? 1500,
            fixationDurationMs: manualFixationDurationMs ?? 500,
            itiRangeMs: manualITIRangeMs ?? 800...1200,
            incongruentRatio: manualIncongruentRatio ?? 0.5
        )
    }

    func spec(for level: Int) -> FlankerLevelSpec {
        switch min(max(level, 1), 6) {
        case 1:
            return FlankerLevelSpec(level: 1, trialsPerBlock: 16, stimulusDurationMs: 350, responseWindowMs: 1800, fixationDurationMs: 450, itiRangeMs: 700...950, incongruentRatio: 0.40)
        case 2:
            return FlankerLevelSpec(level: 2, trialsPerBlock: 16, stimulusDurationMs: 300, responseWindowMs: 1600, fixationDurationMs: 400, itiRangeMs: 650...900, incongruentRatio: 0.45)
        case 3:
            return FlankerLevelSpec(level: 3, trialsPerBlock: 16, stimulusDurationMs: 250, responseWindowMs: 1400, fixationDurationMs: 350, itiRangeMs: 600...850, incongruentRatio: 0.50)
        case 4:
            return FlankerLevelSpec(level: 4, trialsPerBlock: 16, stimulusDurationMs: 220, responseWindowMs: 1250, fixationDurationMs: 320, itiRangeMs: 550...800, incongruentRatio: 0.55)
        case 5:
            return FlankerLevelSpec(level: 5, trialsPerBlock: 16, stimulusDurationMs: 200, responseWindowMs: 1150, fixationDurationMs: 280, itiRangeMs: 500...750, incongruentRatio: 0.60)
        default:
            return FlankerLevelSpec(level: 6, trialsPerBlock: 16, stimulusDurationMs: 180, responseWindowMs: 1050, fixationDurationMs: 240, itiRangeMs: 450...700, incongruentRatio: 0.65)
        }
    }
}
