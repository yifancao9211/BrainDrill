import Foundation
import Observation

@Observable
final class FlankerEngine {
    let config: FlankerSessionConfig
    let startedAt: Date

    private(set) var trials: [FlankerTrial] = []
    private(set) var currentLevel: Int
    private(set) var currentBlockIndex: Int = 0
    private(set) var currentSpec: FlankerLevelSpec
    private(set) var blockLevelHistory: [Int] = []
    private(set) var blockOutcomes: [AdaptiveBlockOutcome] = []
    private(set) var lastBlockOutcome: AdaptiveBlockOutcome?
    private(set) var lastBlockPerformanceIndex: Double?
    private(set) var currentTrialIndex: Int = 0
    private(set) var currentBlockStartIndex: Int = 0
    private(set) var currentBlockTrialCount: Int
    private(set) var results: [FlankerTrialResult] = []
    private(set) var phase: Phase = .idle

    private(set) var stimulusOnsetTime: Date?

    enum Phase: Equatable, Hashable {
        case idle
        case fixation
        case stimulus
        case feedback(correct: Bool)
        case waitingForResponse
        case iti
        case blockBreak(blockIndex: Int, outcome: AdaptiveBlockOutcome, nextLevel: Int)
        case completed
    }

    var currentTrial: FlankerTrial? {
        guard currentTrialIndex < trials.count else { return nil }
        return trials[currentTrialIndex]
    }

    var currentBlock: Int {
        currentBlockIndex
    }

    var trialInBlock: Int {
        currentTrialIndex - currentBlockStartIndex
    }

    var completionFraction: Double {
        let blockProgress = Double(trialInBlock) / Double(max(currentBlockTrialCount, 1))
        return min(1, (Double(currentBlockIndex) + blockProgress) / Double(max(config.blockCount, 1)))
    }

    var isComplete: Bool { phase == .completed }
    var totalBlocks: Int { config.blockCount }

    init(config: FlankerSessionConfig, startedAt: Date = Date()) {
        self.config = config
        self.startedAt = startedAt
        self.currentLevel = config.startingLevel ?? config.initialSpec.level
        self.currentSpec = config.initialSpec
        self.currentBlockTrialCount = config.initialSpec.trialsPerBlock
        self.blockLevelHistory = [self.currentLevel]
        if config.isAdaptive {
            self.trials = Self.generateTrials(spec: config.initialSpec, startId: 0)
        } else {
            var startId = 0
            for _ in 0..<config.blockCount {
                let blockTrials = Self.generateTrials(spec: config.initialSpec, startId: startId)
                self.trials.append(contentsOf: blockTrials)
                startId += blockTrials.count
            }
        }
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
        if currentTrialIndex >= currentBlockStartIndex + currentBlockTrialCount {
            if currentBlockIndex + 1 >= config.blockCount {
                phase = .completed
                return
            }

            let (outcome, nextLevel, performanceIndex) = evaluateCurrentBlock()
            lastBlockOutcome = outcome
            lastBlockPerformanceIndex = performanceIndex
            blockOutcomes.append(outcome)
            currentBlockIndex += 1
            phase = .blockBreak(blockIndex: currentBlockIndex, outcome: outcome, nextLevel: nextLevel)
        } else {
            phase = .iti
        }
    }

    func startNextBlock(level: Int) {
        currentLevel = level
        blockLevelHistory.append(level)
        currentSpec = config.isAdaptive ? config.spec(for: level) : currentSpec
        currentBlockStartIndex = currentTrialIndex
        currentBlockTrialCount = currentSpec.trialsPerBlock
        if config.isAdaptive {
            let blockTrials = Self.generateTrials(spec: currentSpec, startId: trials.count)
            trials.append(contentsOf: blockTrials)
        }
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
            stimulusDurationMs: currentSpec.stimulusDurationMs
        )
    }

    func randomITI() -> Int {
        Int.random(in: currentSpec.itiRangeMs)
    }

    private func evaluateCurrentBlock() -> (AdaptiveBlockOutcome, Int, Double) {
        let blockResults = results.filter { $0.trialIndex >= currentBlockStartIndex && $0.trialIndex < currentBlockStartIndex + currentBlockTrialCount }
        let accuracy = blockResults.isEmpty ? 0 : Double(blockResults.filter(\.responseCorrect).count) / Double(blockResults.count)
        let congruentRT = timeAverage(blockResults.filter { $0.type == .congruent && $0.responseCorrect }.compactMap(\.reactionTime)) ?? 0
        let incongruentRT = timeAverage(blockResults.filter { $0.type == .incongruent && $0.responseCorrect }.compactMap(\.reactionTime)) ?? 0
        let speedScore = clamp((1_200 - incongruentRT * 1_000) / 780)
        let conflictScore = clamp((220 - max(0, (incongruentRT - congruentRT) * 1_000)) / 180)
        let performanceIndex = clamp(0.45 * accuracy + 0.35 * speedScore + 0.20 * conflictScore)

        var nextLevel = currentLevel
        let outcome: AdaptiveBlockOutcome
        if accuracy >= 0.90 && performanceIndex >= 0.78 {
            nextLevel = min(currentLevel + 1, 6)
            outcome = nextLevel > currentLevel ? .promote : .stay
        } else if accuracy < 0.72 || performanceIndex < 0.55 {
            nextLevel = max(currentLevel - 1, 1)
            outcome = nextLevel < currentLevel ? .demote : .stay
        } else {
            outcome = .stay
        }

        return (outcome, nextLevel, performanceIndex)
    }

    private static func generateTrials(spec: FlankerLevelSpec, startId: Int) -> [FlankerTrial] {
        var trials: [FlankerTrial] = []
        let total = spec.trialsPerBlock
        let incongruentCount = Int(round(Double(total) * spec.incongruentRatio))

        for i in 0..<total {
            let isCongruent = i >= incongruentCount
            let targetDir: FlankerDirection = Bool.random() ? .left : .right
            let flankerDir = isCongruent ? targetDir : (targetDir == .left ? .right : .left)
            trials.append(FlankerTrial(
                id: startId + i,
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

private func clamp(_ value: Double) -> Double {
    min(max(value, 0), 1)
}
