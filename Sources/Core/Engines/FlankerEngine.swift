import Foundation
import Observation

@Observable
final class FlankerEngine {
    let config: FlankerSessionConfig
    let trials: [FlankerTrial]
    let startedAt: Date

    private(set) var currentTrialIndex: Int = 0
    private(set) var results: [FlankerTrialResult] = []
    private(set) var phase: Phase = .idle

    private(set) var stimulusOnsetTime: Date?

    enum Phase: Equatable {
        case idle
        case fixation
        case stimulus
        case feedback(correct: Bool)
        case waitingForResponse
        case iti
        case blockBreak(blockIndex: Int)
        case completed
    }

    var currentTrial: FlankerTrial? {
        guard currentTrialIndex < trials.count else { return nil }
        return trials[currentTrialIndex]
    }

    var currentBlock: Int {
        currentTrialIndex / config.trialsPerBlock
    }

    var trialInBlock: Int {
        currentTrialIndex % config.trialsPerBlock
    }

    var completionFraction: Double {
        Double(currentTrialIndex) / Double(trials.count)
    }

    var isComplete: Bool { phase == .completed }

    init(config: FlankerSessionConfig, startedAt: Date = Date()) {
        self.config = config
        self.startedAt = startedAt
        self.trials = Self.generateTrials(config: config)
    }

    func beginTrial() {
        phase = .fixation
    }

    func showStimulus() {
        phase = .stimulus
        stimulusOnsetTime = Date()
    }

    func enterResponseWindow() {
        phase = .waitingForResponse
    }

    func recordResponse(_ direction: FlankerDirection, at date: Date) -> FlankerTrialResult? {
        guard let trial = currentTrial, phase == .stimulus || phase == .waitingForResponse else { return nil }
        let correct = direction == trial.targetDirection
        let rt = stimulusOnsetTime.map { date.timeIntervalSince($0) }
        let result = FlankerTrialResult(trialIndex: currentTrialIndex, type: trial.type, responseCorrect: correct, reactionTime: rt)
        results.append(result)
        phase = .feedback(correct: correct)
        return result
    }

    func recordTimeout() {
        guard let trial = currentTrial else { return }
        let result = FlankerTrialResult(trialIndex: currentTrialIndex, type: trial.type, responseCorrect: false, reactionTime: nil)
        results.append(result)
        phase = .feedback(correct: false)
    }

    func advanceToNext() {
        currentTrialIndex += 1
        if currentTrialIndex >= trials.count {
            phase = .completed
        } else if currentTrialIndex % config.trialsPerBlock == 0 {
            phase = .blockBreak(blockIndex: currentBlock)
        } else {
            phase = .iti
        }
    }

    func endBlockBreak() {
        phase = .idle
    }

    func computeMetrics() -> FlankerMetrics {
        let congruent = results.filter { $0.type == .congruent }
        let incongruent = results.filter { $0.type == .incongruent }
        let correctCongruent = congruent.filter(\.responseCorrect)
        let correctIncongruent = incongruent.filter(\.responseCorrect)

        let avgCongruent = timeAverage(correctCongruent.compactMap(\.reactionTime)) ?? 0
        let avgIncongruent = timeAverage(correctIncongruent.compactMap(\.reactionTime)) ?? 0
        let totalCorrect = results.filter(\.responseCorrect).count
        let accuracy = results.isEmpty ? 0 : Double(totalCorrect) / Double(results.count)

        return FlankerMetrics(
            totalTrials: results.count,
            congruentRT: avgCongruent,
            incongruentRT: avgIncongruent,
            conflictCost: avgIncongruent - avgCongruent,
            accuracy: accuracy,
            stimulusDurationMs: config.stimulusDurationMs
        )
    }

    func randomITI() -> Int {
        Int.random(in: config.itiRangeMs)
    }

    private static func generateTrials(config: FlankerSessionConfig) -> [FlankerTrial] {
        var trials: [FlankerTrial] = []
        let total = config.trialsPerBlock * config.blockCount
        let halfTrials = total / 2

        for i in 0..<total {
            let isCongruent = i < halfTrials
            let targetDir: FlankerDirection = Bool.random() ? .left : .right
            let flankerDir = isCongruent ? targetDir : (targetDir == .left ? .right : .left)
            trials.append(FlankerTrial(
                id: i,
                type: isCongruent ? .congruent : .incongruent,
                targetDirection: targetDir,
                flankerDirection: flankerDir
            ))
        }
        return trials.shuffled()
    }
}

private func timeAverage(_ values: [TimeInterval]) -> TimeInterval? {
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +) / Double(values.count)
}
