import Foundation
import Observation

@Observable
final class GoNoGoEngine {
    let config: GoNoGoSessionConfig
    let startedAt: Date

    private(set) var trials: [GoNoGoTrial] = []
    private(set) var currentLevel: Int
    private(set) var currentBlockIndex: Int = 0
    private(set) var currentSpec: GoNoGoLevelSpec
    private(set) var blockLevelHistory: [Int] = []
    private(set) var blockOutcomes: [AdaptiveBlockOutcome] = []
    private(set) var lastBlockOutcome: AdaptiveBlockOutcome?
    private(set) var lastBlockPerformanceIndex: Double?
    private(set) var currentTrialIndex: Int = 0
    private(set) var currentBlockStartIndex: Int = 0
    private(set) var currentBlockTrialCount: Int
    private(set) var results: [GoNoGoTrialResult] = []
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

    var currentTrial: GoNoGoTrial? {
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

    init(config: GoNoGoSessionConfig, startedAt: Date = Date()) {
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
        Int.random(in: currentSpec.itiRangeMs)
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

    private func evaluateCurrentBlock() -> (AdaptiveBlockOutcome, Int, Double) {
        let blockResults = results.filter { $0.trialIndex >= currentBlockStartIndex && $0.trialIndex < currentBlockStartIndex + currentBlockTrialCount }
        let goTrials = blockResults.filter { $0.stimulusType == .go }
        let noGoTrials = blockResults.filter { $0.stimulusType == .noGo }

        let goAccuracy = goTrials.isEmpty ? 0 : Double(goTrials.filter(\.responded).count) / Double(goTrials.count)
        let noGoAccuracy = noGoTrials.isEmpty ? 0 : Double(noGoTrials.filter { !$0.responded }.count) / Double(noGoTrials.count)
        let hitRate = min(max(goAccuracy, 0.01), 0.99)
        let faRate = min(max(1.0 - noGoAccuracy, 0.01), 0.99)
        let dPrimeScore = clamp((Self.zScore(hitRate) - Self.zScore(faRate)) / 4.0)
        let avgGoRT = timeAverage(goTrials.filter(\.responded).compactMap(\.reactionTime)) ?? 0
        let speedScore = clamp((850 - avgGoRT * 1_000) / 530)
        let performanceIndex = clamp(0.40 * dPrimeScore + 0.35 * noGoAccuracy + 0.25 * speedScore)

        var nextLevel = currentLevel
        let outcome: AdaptiveBlockOutcome
        if noGoAccuracy >= 0.82 && goAccuracy >= 0.90 && performanceIndex >= 0.78 {
            nextLevel = min(currentLevel + 1, 6)
            outcome = nextLevel > currentLevel ? .promote : .stay
        } else if noGoAccuracy < 0.65 || goAccuracy < 0.75 || performanceIndex < 0.55 {
            nextLevel = max(currentLevel - 1, 1)
            outcome = nextLevel < currentLevel ? .demote : .stay
        } else {
            outcome = .stay
        }

        return (outcome, nextLevel, performanceIndex)
    }

    private static func generateTrials(spec: GoNoGoLevelSpec, startId: Int) -> [GoNoGoTrial] {
        var trials: [GoNoGoTrial] = []
        let total = spec.trialsPerBlock
        let goCount = Int(Double(total) * spec.goRatio)
        let noGoCount = total - goCount

        var types: [GoNoGoStimulusType] = Array(repeating: .go, count: goCount) + Array(repeating: .noGo, count: noGoCount)
        types.shuffle()

        for (i, type) in types.enumerated() {
            trials.append(GoNoGoTrial(id: startId + i, stimulusType: type))
        }
        return trials
    }
}

private func timeAverage(_ values: [TimeInterval]) -> TimeInterval? {
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +) / Double(values.count)
}

private func clamp(_ value: Double) -> Double {
    min(max(value, 0), 1)
}
