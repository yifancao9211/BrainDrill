import Foundation

enum StopSignalDirection: String, Codable, Equatable {
    case left
    case right
}

struct StopSignalTrial: Identifiable, Equatable {
    let id: Int
    let correctDirection: StopSignalDirection
    let hasStopSignal: Bool
}

struct StopSignalTrialResult: Equatable {
    let trialIndex: Int
    let hasStopSignal: Bool
    let responded: Bool
    let responseDirection: StopSignalDirection?
    let correct: Bool
    let inhibited: Bool
    let reactionTime: TimeInterval?
    let stopSignalDelay: Int?

    init(trial: StopSignalTrial, responseDirection: StopSignalDirection?, reactionTime: TimeInterval?, stopSignalDelay: Int?) {
        self.trialIndex = trial.id
        self.hasStopSignal = trial.hasStopSignal
        self.responded = responseDirection != nil
        self.responseDirection = responseDirection
        self.reactionTime = reactionTime
        self.stopSignalDelay = stopSignalDelay

        if trial.hasStopSignal {
            self.inhibited = responseDirection == nil
            self.correct = self.inhibited
        } else {
            self.inhibited = false
            self.correct = responseDirection == trial.correctDirection
        }
    }
}

struct StopSignalSessionConfig: Equatable {
    var trialsPerBlock: Int
    var blockCount: Int
    var stopRatio: Double
    var initialSSD: Int
    var ssdStepMs: Int
    var fixationMs: Int
    var responseWindowMs: Int
    var itiRangeMs: ClosedRange<Int>

    init(
        trialsPerBlock: Int = 40,
        blockCount: Int = 2,
        stopRatio: Double = 0.25,
        initialSSD: Int = 250,
        ssdStepMs: Int = 50,
        fixationMs: Int = 500,
        responseWindowMs: Int = 1000,
        itiRangeMs: ClosedRange<Int> = 500...1500
    ) {
        self.trialsPerBlock = trialsPerBlock
        self.blockCount = blockCount
        self.stopRatio = stopRatio
        self.initialSSD = initialSSD
        self.ssdStepMs = ssdStepMs
        self.fixationMs = fixationMs
        self.responseWindowMs = responseWindowMs
        self.itiRangeMs = itiRangeMs
    }
}
