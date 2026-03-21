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

struct FlankerSessionConfig: Equatable {
    var trialsPerBlock: Int = 40
    var blockCount: Int = 2
    var stimulusDurationMs: Int = 200
    var responseWindowMs: Int = 1500
    var fixationDurationMs: Int = 500
    var itiRangeMs: ClosedRange<Int> = 800...1200
}
