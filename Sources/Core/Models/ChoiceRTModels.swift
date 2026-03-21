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

struct ChoiceRTSessionConfig: Equatable {
    var choiceCount: Int
    var trialsPerBlock: Int
    var blockCount: Int
    var fixationMs: Int
    var responseWindowMs: Int
    var itiRangeMs: ClosedRange<Int>

    init(
        choiceCount: Int = 2,
        trialsPerBlock: Int = 30,
        blockCount: Int = 1,
        fixationMs: Int = 500,
        responseWindowMs: Int = 2000,
        itiRangeMs: ClosedRange<Int> = 300...600
    ) {
        self.choiceCount = choiceCount
        self.trialsPerBlock = trialsPerBlock
        self.blockCount = blockCount
        self.fixationMs = fixationMs
        self.responseWindowMs = responseWindowMs
        self.itiRangeMs = itiRangeMs
    }
}
