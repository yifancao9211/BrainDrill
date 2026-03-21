import Foundation

struct NBackTrial: Identifiable, Equatable {
    let id: Int
    let stimulus: Int
    let isTarget: Bool
}

struct NBackTrialResult: Codable, Equatable {
    let trialIndex: Int
    let isTarget: Bool
    let responded: Bool
    let reactionTime: TimeInterval?
}

struct NBackSessionConfig: Equatable {
    var startingN: Int = 1
    var maxN: Int = 9
    var trialsPerBlock: Int = 20
    var blockCount: Int = 3
    var stimulusDurationMs: Int = 500
    var isiMs: Int = 2500
    var targetRatio: Double = 0.30
    var promoteThreshold: Double = 0.80
    var demoteThreshold: Double = 0.50
    var stimulusRange: ClosedRange<Int> = 1...9
}
