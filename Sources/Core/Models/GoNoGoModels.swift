import Foundation

enum GoNoGoStimulusType: String, Codable, Equatable {
    case go
    case noGo
}

struct GoNoGoTrial: Identifiable, Equatable {
    let id: Int
    let stimulusType: GoNoGoStimulusType
}

struct GoNoGoTrialResult: Codable, Equatable {
    let trialIndex: Int
    let stimulusType: GoNoGoStimulusType
    let responded: Bool
    let reactionTime: TimeInterval?
}

struct GoNoGoLevelSpec: Equatable {
    let level: Int
    let trialsPerBlock: Int
    let goRatio: Double
    let stimulusDurationMs: Int
    let responseWindowMs: Int
    let fixationDurationMs: Int
    let itiRangeMs: ClosedRange<Int>
}

struct GoNoGoSessionConfig: Equatable {
    var blockCount: Int
    var startingLevel: Int?
    var manualTrialsPerBlock: Int?
    var manualGoRatio: Double?
    var manualStimulusDurationMs: Int?
    var manualResponseWindowMs: Int?
    var manualFixationDurationMs: Int?
    var manualITIRangeMs: ClosedRange<Int>?

    init(
        trialsPerBlock: Int? = 24,
        blockCount: Int = 1,
        goRatio: Double? = 0.75,
        stimulusDurationMs: Int? = 500,
        responseWindowMs: Int? = 1000,
        fixationDurationMs: Int? = 300,
        itiRangeMs: ClosedRange<Int>? = 500...1500,
        startingLevel: Int? = nil
    ) {
        self.blockCount = blockCount
        self.startingLevel = startingLevel
        self.manualTrialsPerBlock = trialsPerBlock
        self.manualGoRatio = goRatio
        self.manualStimulusDurationMs = stimulusDurationMs
        self.manualResponseWindowMs = responseWindowMs
        self.manualFixationDurationMs = fixationDurationMs
        self.manualITIRangeMs = itiRangeMs
    }

    var isAdaptive: Bool { startingLevel != nil }

    var initialSpec: GoNoGoLevelSpec {
        if let startingLevel {
            return spec(for: startingLevel)
        }
        return GoNoGoLevelSpec(
            level: 3,
            trialsPerBlock: manualTrialsPerBlock ?? 24,
            goRatio: manualGoRatio ?? 0.75,
            stimulusDurationMs: manualStimulusDurationMs ?? 500,
            responseWindowMs: manualResponseWindowMs ?? 1000,
            fixationDurationMs: manualFixationDurationMs ?? 300,
            itiRangeMs: manualITIRangeMs ?? 500...1500
        )
    }

    func spec(for level: Int) -> GoNoGoLevelSpec {
        switch min(max(level, 1), 6) {
        case 1:
            return GoNoGoLevelSpec(level: 1, trialsPerBlock: 18, goRatio: 0.65, stimulusDurationMs: 700, responseWindowMs: 1100, fixationDurationMs: 320, itiRangeMs: 550...950)
        case 2:
            return GoNoGoLevelSpec(level: 2, trialsPerBlock: 18, goRatio: 0.70, stimulusDurationMs: 600, responseWindowMs: 1000, fixationDurationMs: 280, itiRangeMs: 500...900)
        case 3:
            return GoNoGoLevelSpec(level: 3, trialsPerBlock: 18, goRatio: 0.75, stimulusDurationMs: 500, responseWindowMs: 900, fixationDurationMs: 260, itiRangeMs: 450...850)
        case 4:
            return GoNoGoLevelSpec(level: 4, trialsPerBlock: 18, goRatio: 0.80, stimulusDurationMs: 450, responseWindowMs: 850, fixationDurationMs: 230, itiRangeMs: 420...800)
        case 5:
            return GoNoGoLevelSpec(level: 5, trialsPerBlock: 18, goRatio: 0.82, stimulusDurationMs: 400, responseWindowMs: 800, fixationDurationMs: 220, itiRangeMs: 400...750)
        default:
            return GoNoGoLevelSpec(level: 6, trialsPerBlock: 18, goRatio: 0.85, stimulusDurationMs: 350, responseWindowMs: 760, fixationDurationMs: 200, itiRangeMs: 380...700)
        }
    }
}
