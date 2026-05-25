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
    let decisionInterval: TimeInterval?

    init(
        trialIndex: Int,
        isTarget: Bool,
        responded: Bool,
        reactionTime: TimeInterval?,
        decisionInterval: TimeInterval? = nil
    ) {
        self.trialIndex = trialIndex
        self.isTarget = isTarget
        self.responded = responded
        self.reactionTime = reactionTime
        self.decisionInterval = decisionInterval
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        trialIndex = try c.decode(Int.self, forKey: .trialIndex)
        isTarget = try c.decode(Bool.self, forKey: .isTarget)
        responded = try c.decode(Bool.self, forKey: .responded)
        reactionTime = try c.decodeIfPresent(TimeInterval.self, forKey: .reactionTime)
        decisionInterval = try c.decodeIfPresent(TimeInterval.self, forKey: .decisionInterval)
    }
}

struct NBackSessionConfig: Equatable {
    var startingN: Int = 1
    var maxN: Int = 9
    var trialsPerBlock: Int = 12
    var blockCount: Int = 2
    var stimulusDurationMs: Int = 800
    var isiMs: Int = 1400
    var internalSkillScore: Double = 35
    var targetRatio: Double = 0.30
    var promoteThreshold: Double = 0.80
    var demoteThreshold: Double = 0.50
    var stimulusRange: ClosedRange<Int> = 1...9
}
