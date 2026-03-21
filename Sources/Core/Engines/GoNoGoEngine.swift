import Foundation
import Observation

@Observable
final class GoNoGoEngine {
    let config: GoNoGoSessionConfig
    let trials: [GoNoGoTrial]
    let startedAt: Date

    private(set) var currentTrialIndex: Int = 0
    private(set) var results: [GoNoGoTrialResult] = []
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

    var currentTrial: GoNoGoTrial? {
        guard currentTrialIndex < trials.count else { return nil }
        return trials[currentTrialIndex]
    }

    var completionFraction: Double {
        Double(currentTrialIndex) / Double(trials.count)
    }

    var isComplete: Bool { phase == .completed }

    init(config: GoNoGoSessionConfig, startedAt: Date = Date()) {
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

    func recordTap(at date: Date) -> GoNoGoTrialResult? {
        guard let trial = currentTrial, phase == .stimulus else { return nil }
        let rt = stimulusOnsetTime.map { date.timeIntervalSince($0) }
        let correct = trial.stimulusType == .go
        let result = GoNoGoTrialResult(trialIndex: currentTrialIndex, stimulusType: trial.stimulusType, responded: true, reactionTime: rt)
        results.append(result)
        phase = .feedback(correct: correct)
        return result
    }

    func recordTimeout() {
        guard let trial = currentTrial else { return }
        let correct = trial.stimulusType == .noGo
        let result = GoNoGoTrialResult(trialIndex: currentTrialIndex, stimulusType: trial.stimulusType, responded: false, reactionTime: nil)
        results.append(result)
        phase = .feedback(correct: correct)
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

    func computeMetrics() -> GoNoGoMetrics {
        let goTrials = results.filter { $0.stimulusType == .go }
        let noGoTrials = results.filter { $0.stimulusType == .noGo }

        let goCorrect = goTrials.filter(\.responded)
        let goAccuracy = goTrials.isEmpty ? 0 : Double(goCorrect.count) / Double(goTrials.count)
        let goRT = goCorrect.compactMap(\.reactionTime)
        let avgGoRT = goRT.isEmpty ? 0 : goRT.reduce(0, +) / Double(goRT.count)

        let noGoCorrect = noGoTrials.filter { !$0.responded }
        let noGoAccuracy = noGoTrials.isEmpty ? 0 : Double(noGoCorrect.count) / Double(noGoTrials.count)

        let hitRate = min(max(goAccuracy, 0.01), 0.99)
        let faRate = min(max(1.0 - noGoAccuracy, 0.01), 0.99)
        let dPrime = Self.zScore(hitRate) - Self.zScore(faRate)

        return GoNoGoMetrics(
            totalTrials: results.count,
            goRT: avgGoRT,
            goAccuracy: goAccuracy,
            noGoAccuracy: noGoAccuracy,
            dPrime: dPrime
        )
    }

    func randomITI() -> Int {
        Int.random(in: config.itiRangeMs)
    }

    private static func zScore(_ p: Double) -> Double {
        let clamped = min(max(p, 0.0001), 0.9999)
        // Rational approximation (Abramowitz & Stegun 26.2.23)
        let t = sqrt(-2.0 * log(clamped < 0.5 ? clamped : 1.0 - clamped))
        let c0 = 2.515517, c1 = 0.802853, c2 = 0.010328
        let d1 = 1.432788, d2 = 0.189269, d3 = 0.001308
        let z = t - (c0 + c1 * t + c2 * t * t) / (1.0 + d1 * t + d2 * t * t + d3 * t * t * t)
        return clamped < 0.5 ? -z : z
    }

    private static func generateTrials(config: GoNoGoSessionConfig) -> [GoNoGoTrial] {
        var trials: [GoNoGoTrial] = []
        let total = config.trialsPerBlock * config.blockCount
        let goCount = Int(Double(total) * config.goRatio)
        let noGoCount = total - goCount

        var types: [GoNoGoStimulusType] = Array(repeating: .go, count: goCount) + Array(repeating: .noGo, count: noGoCount)
        types.shuffle()

        for (i, type) in types.enumerated() {
            trials.append(GoNoGoTrial(id: i, stimulusType: type))
        }
        return trials
    }
}
