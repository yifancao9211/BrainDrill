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

struct GoNoGoSessionConfig: Equatable {
    var trialsPerBlock: Int = 40
    var blockCount: Int = 2
    var goRatio: Double = 0.75
    var stimulusDurationMs: Int = 500
    var responseWindowMs: Int = 1000
    var fixationDurationMs: Int = 300
    var itiRangeMs: ClosedRange<Int> = 500...1500
}
