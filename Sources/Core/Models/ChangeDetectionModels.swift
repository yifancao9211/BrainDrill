import Foundation

struct ChangeDetectionTrial: Identifiable, Equatable {
    let id: Int
    let originalColors: [Int]
    let positions: [CGPoint]
    let changedIndex: Int?
    let changedColor: Int?
    let setSize: Int

    var isChangePresent: Bool { changedIndex != nil }

    var probeColors: [Int] {
        guard let idx = changedIndex, let newColor = changedColor else {
            return originalColors
        }
        var result = originalColors
        result[idx] = newColor
        return result
    }
}

struct ChangeDetectionTrialResult: Equatable {
    let trialIndex: Int
    let setSize: Int
    let changePresent: Bool
    let userSaidChanged: Bool
    let correct: Bool
    let reactionTime: TimeInterval?

    var isHit: Bool { changePresent && userSaidChanged }
    var isFalseAlarm: Bool { !changePresent && userSaidChanged }
    var isMiss: Bool { changePresent && !userSaidChanged }
    var isCorrectRejection: Bool { !changePresent && !userSaidChanged }

    init(trial: ChangeDetectionTrial, userSaidChanged: Bool, reactionTime: TimeInterval?) {
        self.trialIndex = trial.id
        self.setSize = trial.setSize
        self.changePresent = trial.isChangePresent
        self.userSaidChanged = userSaidChanged
        self.reactionTime = reactionTime
        self.correct = (changePresent == userSaidChanged)
    }
}

struct ChangeDetectionSessionConfig: Equatable {
    var initialSetSize: Int
    var maxSetSize: Int
    var encodingMs: Int
    var retentionMs: Int
    var trialsPerBlock: Int
    var blockCount: Int
    var changeRatio: Double
    var consecutiveCorrectToAdvance: Int
    var consecutiveWrongToDemote: Int

    static let availableColors = 9

    init(
        initialSetSize: Int = 3,
        maxSetSize: Int = 8,
        encodingMs: Int = 500,
        retentionMs: Int = 900,
        trialsPerBlock: Int = 20,
        blockCount: Int = 1,
        changeRatio: Double = 0.5,
        consecutiveCorrectToAdvance: Int = 4,
        consecutiveWrongToDemote: Int = 3
    ) {
        self.initialSetSize = initialSetSize
        self.maxSetSize = maxSetSize
        self.encodingMs = encodingMs
        self.retentionMs = retentionMs
        self.trialsPerBlock = trialsPerBlock
        self.blockCount = blockCount
        self.changeRatio = changeRatio
        self.consecutiveCorrectToAdvance = consecutiveCorrectToAdvance
        self.consecutiveWrongToDemote = consecutiveWrongToDemote
    }
}
