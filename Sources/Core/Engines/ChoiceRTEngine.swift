import Foundation
import Observation

@Observable
final class ChoiceRTEngine {
    let config: ChoiceRTSessionConfig
    let startedAt: Date

    private(set) var trials: [ChoiceRTTrial] = []
    private(set) var currentLevel: Int
    private(set) var currentBlockIndex: Int = 0
    private(set) var currentSpec: ChoiceRTLevelSpec
    private(set) var blockLevelHistory: [Int] = []
    private(set) var blockOutcomes: [AdaptiveBlockOutcome] = []
    private(set) var lastBlockOutcome: AdaptiveBlockOutcome?
    private(set) var lastBlockPerformanceIndex: Double?
    private(set) var currentTrialIndex: Int = 0
    private(set) var currentBlockStartIndex: Int = 0
    private(set) var currentBlockTrialCount: Int
    private(set) var results: [ChoiceRTTrialResult] = []
    private(set) var phase: Phase = .idle
    private(set) var stimulusOnsetTime: Date?

    enum Phase: Equatable, Hashable {
        case idle
        case fixation
        case stimulus
        case feedback(correct: Bool)
        case iti
        case blockBreak(blockIndex: Int, outcome: AdaptiveBlockOutcome, nextLevel: Int)
        case completed
    }

    var currentTrial: ChoiceRTTrial? {
        guard currentTrialIndex < trials.count else { return nil }
        return trials[currentTrialIndex]
    }

    var currentBlock: Int {
        currentBlockIndex
    }

    var completionFraction: Double {
        let blockProgress = Double(currentTrialIndex - currentBlockStartIndex) / Double(max(currentBlockTrialCount, 1))
        return min(1, (Double(currentBlockIndex) + blockProgress) / Double(max(config.blockCount, 1)))
    }

    var isComplete: Bool { phase == .completed }
    var totalBlocks: Int { config.blockCount }

    init(config: ChoiceRTSessionConfig, startedAt: Date = Date()) {
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

    func recordResponse(_ responseIndex: Int, at date: Date = Date()) -> ChoiceRTTrialResult? {
        guard let trial = currentTrial, phase == .stimulus else { return nil }
        let rt = stimulusOnsetTime.map { date.timeIntervalSince($0) }
        let result = ChoiceRTTrialResult(trial: trial, responseIndex: responseIndex, reactionTime: rt)
        results.append(result)
        phase = .feedback(correct: result.correct)
        return result
    }

    func recordTimeout() {
        guard let trial = currentTrial else { return }
        let result = ChoiceRTTrialResult(trial: trial, responseIndex: nil, reactionTime: nil)
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

    func randomITI() -> Int {
        Int.random(in: currentSpec.itiRangeMs)
    }

    func computeMetrics() -> ChoiceRTMetrics {
        let validResults = results.filter { $0.reactionTime != nil && !$0.isAnticipation }
        let correctResults = validResults.filter(\.correct)
        let correctRTs = correctResults.compactMap(\.reactionTime)

        let medRT = MetricsCalculator.medianRT(correctRTs)
        let sdRT = MetricsCalculator.standardDeviation(correctRTs)

        let trialPairs = results.enumerated().map { (idx, r) -> (correct: Bool, rt: TimeInterval?) in
            (r.correct, r.reactionTime)
        }
        let pes = MetricsCalculator.postErrorSlowing(results: trialPairs)

        let anticipations = results.filter(\.isAnticipation).count
        let accuracy = validResults.isEmpty ? 0 : Double(correctResults.count) / Double(validResults.count)

        return ChoiceRTMetrics(
            totalTrials: results.count,
            medianRT: medRT,
            rtStandardDeviation: sdRT,
            accuracy: accuracy,
            postErrorSlowing: pes,
            anticipationCount: anticipations,
            choiceCount: currentSpec.choiceCount
        )
    }

    private func evaluateCurrentBlock() -> (AdaptiveBlockOutcome, Int, Double) {
        let blockResults = results.filter { $0.trialIndex >= currentBlockStartIndex && $0.trialIndex < currentBlockStartIndex + currentBlockTrialCount }
        let validResults = blockResults.filter { $0.reactionTime != nil && !$0.isAnticipation }
        let correctResults = validResults.filter(\.correct)
        let correctRTs = correctResults.compactMap(\.reactionTime)

        let accuracy = validResults.isEmpty ? 0 : Double(correctResults.count) / Double(validResults.count)
        let medianRT = MetricsCalculator.medianRT(correctRTs) * 1_000
        let rtScore = clamp((1_100 - medianRT) / 820)
        let anticipationRate = blockResults.isEmpty ? 0 : Double(blockResults.filter(\.isAnticipation).count) / Double(blockResults.count)
        let sdMs = MetricsCalculator.standardDeviation(correctRTs) * 1_000
        let stabilityPenalty = clamp(sdMs / 350.0)
        let stabilityScore = clamp(1.0 - (0.65 * stabilityPenalty + 0.35 * min(1, anticipationRate / 0.15)))
        let performanceIndex = clamp(0.45 * accuracy + 0.35 * rtScore + 0.20 * stabilityScore)

        var nextLevel = currentLevel
        let outcome: AdaptiveBlockOutcome
        if accuracy >= 0.92 && anticipationRate < 0.08 && performanceIndex >= 0.80 {
            nextLevel = min(currentLevel + 1, 6)
            outcome = nextLevel > currentLevel ? .promote : .stay
        } else if accuracy < 0.75 || anticipationRate > 0.15 || performanceIndex < 0.55 {
            nextLevel = max(currentLevel - 1, 1)
            outcome = nextLevel < currentLevel ? .demote : .stay
        } else {
            outcome = .stay
        }

        return (outcome, nextLevel, performanceIndex)
    }

    private static func generateTrials(spec: ChoiceRTLevelSpec, startId: Int) -> [ChoiceRTTrial] {
        let total = spec.trialsPerBlock
        let stimuli = Array(ChoiceRTStimulus.palette.prefix(spec.choiceCount))

        var trials: [ChoiceRTTrial] = []
        for i in 0..<total {
            let stimIndex = i % stimuli.count
            let stim = ChoiceRTStimulus(
                id: startId + i,
                colorIndex: stimuli[stimIndex].colorIndex,
                label: stimuli[stimIndex].label
            )
            trials.append(ChoiceRTTrial(id: startId + i, stimulus: stim, correctResponseIndex: stimIndex))
        }
        trials.shuffle()
        return trials
    }
}

private func clamp(_ value: Double) -> Double {
    min(max(value, 0), 1)
}
