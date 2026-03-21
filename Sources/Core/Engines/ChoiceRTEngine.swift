import Foundation
import Observation

@Observable
final class ChoiceRTEngine {
    let config: ChoiceRTSessionConfig
    let trials: [ChoiceRTTrial]
    let startedAt: Date

    private(set) var currentTrialIndex: Int = 0
    private(set) var results: [ChoiceRTTrialResult] = []
    private(set) var phase: Phase = .idle
    private(set) var stimulusOnsetTime: Date?

    enum Phase: Equatable, Hashable {
        case idle
        case fixation
        case stimulus
        case feedback(correct: Bool)
        case iti
        case blockBreak(blockIndex: Int)
        case completed
    }

    var currentTrial: ChoiceRTTrial? {
        guard currentTrialIndex < trials.count else { return nil }
        return trials[currentTrialIndex]
    }

    var completionFraction: Double {
        Double(currentTrialIndex) / Double(trials.count)
    }

    var isComplete: Bool { phase == .completed }

    init(config: ChoiceRTSessionConfig, startedAt: Date = Date()) {
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
        if currentTrialIndex >= trials.count {
            phase = .completed
        } else if currentTrialIndex % config.trialsPerBlock == 0 {
            phase = .blockBreak(blockIndex: currentTrialIndex / config.trialsPerBlock)
        } else {
            phase = .iti
        }
    }

    func endBlockBreak() {
        phase = .idle
    }

    func randomITI() -> Int {
        Int.random(in: config.itiRangeMs)
    }

    func computeMetrics() -> ChoiceRTMetrics {
        let validResults = results.filter { $0.reactionTime != nil && !$0.isAnticipation }
        let rts = validResults.compactMap(\.reactionTime)
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
            choiceCount: config.choiceCount
        )
    }

    private static func generateTrials(config: ChoiceRTSessionConfig) -> [ChoiceRTTrial] {
        let total = config.trialsPerBlock * config.blockCount
        let stimuli = Array(ChoiceRTStimulus.palette.prefix(config.choiceCount))

        var trials: [ChoiceRTTrial] = []
        for i in 0..<total {
            let stimIndex = i % stimuli.count
            let stim = ChoiceRTStimulus(
                id: i,
                colorIndex: stimuli[stimIndex].colorIndex,
                label: stimuli[stimIndex].label
            )
            trials.append(ChoiceRTTrial(id: i, stimulus: stim, correctResponseIndex: stimIndex))
        }
        trials.shuffle()

        for i in 0..<trials.count {
            let trial = trials[i]
            trials[i] = ChoiceRTTrial(id: i, stimulus: trial.stimulus, correctResponseIndex: trial.correctResponseIndex)
        }

        return trials
    }
}
