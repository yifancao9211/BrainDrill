import Foundation

struct ChoiceRTStimulus: Equatable, Identifiable {
    let id: Int
    let colorIndex: Int
    let label: String

    static let palette: [(label: String, colorIndex: Int)] = [
        ("红", 0), ("蓝", 1), ("绿", 2), ("黄", 3)
    ]
}

struct ChoiceRTTrial: Identifiable, Equatable {
    let id: Int
    let stimulus: ChoiceRTStimulus
    let correctResponseIndex: Int
}

struct ChoiceRTTrialResult: Equatable {
    let trialIndex: Int
    let stimulus: ChoiceRTStimulus
    let responseIndex: Int?
    let correct: Bool
    let reactionTime: TimeInterval?
    let isAnticipation: Bool

    init(trial: ChoiceRTTrial, responseIndex: Int?, reactionTime: TimeInterval?) {
        self.trialIndex = trial.id
        self.stimulus = trial.stimulus
        self.responseIndex = responseIndex
        self.reactionTime = reactionTime

        if let rt = reactionTime {
            self.isAnticipation = rt < MetricsCalculator.anticipationThreshold
        } else {
            self.isAnticipation = false
        }

        if let resp = responseIndex {
            self.correct = resp == trial.correctResponseIndex && !isAnticipation
        } else {
            self.correct = false
        }
    }
}

struct ChoiceRTLevelSpec: Equatable {
    let level: Int
    let choiceCount: Int
    let trialsPerBlock: Int
    let fixationMs: Int
    let responseWindowMs: Int
    let itiRangeMs: ClosedRange<Int>
}

struct ChoiceRTSessionConfig: Equatable {
    var blockCount: Int
    var startingLevel: Int?
    var manualChoiceCount: Int?
    var manualTrialsPerBlock: Int?
    var manualFixationMs: Int?
    var manualResponseWindowMs: Int?
    var manualITIRangeMs: ClosedRange<Int>?

    init(
        choiceCount: Int? = 2,
        trialsPerBlock: Int? = 18,
        blockCount: Int = 1,
        fixationMs: Int? = 500,
        responseWindowMs: Int? = 2000,
        itiRangeMs: ClosedRange<Int>? = 300...600,
        startingLevel: Int? = nil
    ) {
        self.blockCount = blockCount
        self.startingLevel = startingLevel
        self.manualChoiceCount = choiceCount
        self.manualTrialsPerBlock = trialsPerBlock
        self.manualFixationMs = fixationMs
        self.manualResponseWindowMs = responseWindowMs
        self.manualITIRangeMs = itiRangeMs
    }

    var isAdaptive: Bool { startingLevel != nil }

    var choiceCount: Int { initialSpec.choiceCount }
    var trialsPerBlock: Int { initialSpec.trialsPerBlock }
    var fixationMs: Int { initialSpec.fixationMs }
    var responseWindowMs: Int { initialSpec.responseWindowMs }
    var itiRangeMs: ClosedRange<Int> { initialSpec.itiRangeMs }

    var initialSpec: ChoiceRTLevelSpec {
        if let startingLevel {
            return spec(for: startingLevel)
        }
        return ChoiceRTLevelSpec(
            level: 3,
            choiceCount: manualChoiceCount ?? 2,
            trialsPerBlock: manualTrialsPerBlock ?? 18,
            fixationMs: manualFixationMs ?? 500,
            responseWindowMs: manualResponseWindowMs ?? 2000,
            itiRangeMs: manualITIRangeMs ?? 300...600
        )
    }

    func spec(for level: Int) -> ChoiceRTLevelSpec {
        switch min(max(level, 1), 6) {
        case 1:
            return ChoiceRTLevelSpec(level: 1, choiceCount: 2, trialsPerBlock: 12, fixationMs: 450, responseWindowMs: 1600, itiRangeMs: 280...520)
        case 2:
            return ChoiceRTLevelSpec(level: 2, choiceCount: 2, trialsPerBlock: 12, fixationMs: 420, responseWindowMs: 1450, itiRangeMs: 260...500)
        case 3:
            return ChoiceRTLevelSpec(level: 3, choiceCount: 3, trialsPerBlock: 12, fixationMs: 380, responseWindowMs: 1350, itiRangeMs: 240...460)
        case 4:
            return ChoiceRTLevelSpec(level: 4, choiceCount: 3, trialsPerBlock: 12, fixationMs: 340, responseWindowMs: 1200, itiRangeMs: 220...420)
        case 5:
            return ChoiceRTLevelSpec(level: 5, choiceCount: 4, trialsPerBlock: 12, fixationMs: 300, responseWindowMs: 1100, itiRangeMs: 200...380)
        default:
            return ChoiceRTLevelSpec(level: 6, choiceCount: 4, trialsPerBlock: 12, fixationMs: 260, responseWindowMs: 980, itiRangeMs: 180...340)
        }
    }
}
