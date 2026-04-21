import Foundation
import Observation

@Observable
final class FlankerEngine {
    let config: FlankerSessionConfig
    let startedAt: Date

    // Core Engine Logic
    private(set) var staircase: AdaptiveStaircase
    private(set) var currentLevel: Int
    private(set) var currentBlockIndex: Int = 0
    private(set) var currentSpec: FlankerLevelSpec
    private(set) var blockLevelHistory: [Int] = []
    
    // Block Outcomes (Fake for legacy compatibility, not used by true staircase)
    private(set) var blockOutcomes: [AdaptiveBlockOutcome] = []
    private(set) var lastBlockOutcome: AdaptiveBlockOutcome?
    private(set) var lastBlockPerformanceIndex: Double?

    // Trial Tracking
    private(set) var currentTrialIndex: Int = 0
    private(set) var currentBlockStartIndex: Int = 0
    private(set) var currentBlockTrialCount: Int
    private(set) var results: [FlankerTrialResult] = []
    private(set) var phase: Phase = .idle

    private(set) var stimulusOnsetTime: Date?
    private(set) var currentTrial: FlankerTrial?
    
    var isWarmup: Bool { currentTrialIndex < 3 } // First 3 trials are warmup and don't demote

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
        let initialLevel = config.startingLevel ?? config.initialSpec.level
        self.currentLevel = initialLevel
        self.currentSpec = config.initialSpec
        self.staircase = AdaptiveStaircase(startLevel: initialLevel, minLevel: 1, maxLevel: 6, rule: .threeUpOneDown)
        self.currentBlockTrialCount = config.initialSpec.trialsPerBlock
        self.blockLevelHistory = [initialLevel]
    }

    func beginTrial() {
        if currentTrial == nil {
            currentTrial = generateSingleTrial(spec: currentSpec, startId: currentTrialIndex)
        }
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
        
        applyStaircaseMetrics(correct: correct)
        phase = .feedback(correct: correct)
        return result
    }

    func recordTimeout() {
        guard let trial = currentTrial else { return }
        let result = FlankerTrialResult(trialIndex: currentTrialIndex, type: trial.type, responseCorrect: false, reactionTime: nil)
        results.append(result)
        
        applyStaircaseMetrics(correct: false)
        phase = .feedback(correct: false)
    }
    
    private func applyStaircaseMetrics(correct: Bool) {
        if config.isAdaptive && !isWarmup {
            let change = staircase.recordTrial(correct: correct)
            if change != 0 {
                currentLevel = staircase.currentLevel
                currentSpec = config.spec(for: currentLevel)
            }
        }
    }

    func advanceToNext() {
        currentTrialIndex += 1
        currentTrial = nil
        
        if trialInBlock >= currentBlockTrialCount {
            if currentBlockIndex + 1 >= config.blockCount {
                phase = .completed
                return
            }

            let (outcome, nextLevel, performanceIndex) = evaluateCurrentBlockLegacy()
            lastBlockOutcome = outcome
            lastBlockPerformanceIndex = performanceIndex
            blockOutcomes.append(outcome)
            currentBlockIndex += 1
            phase = .blockBreak(blockIndex: currentBlockIndex, outcome: outcome, nextLevel: currentLevel)
        } else {
            phase = .iti
        }
    }

    func startNextBlock(level: Int) {
        // level param is mostly ignored as we use continuous staircase now, 
        // but kept to honor legacy API calls from FlankerTrainingView
        blockLevelHistory.append(currentLevel)
        currentBlockStartIndex = currentTrialIndex
        currentBlockTrialCount = currentSpec.trialsPerBlock
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

    private func evaluateCurrentBlockLegacy() -> (AdaptiveBlockOutcome, Int, Double) {
        let blockResults = results.filter { $0.trialIndex >= currentBlockStartIndex && $0.trialIndex < currentBlockStartIndex + currentBlockTrialCount }
        let accuracy = blockResults.isEmpty ? 0 : Double(blockResults.filter(\.responseCorrect).count) / Double(blockResults.count)
        let congruentRT = timeAverage(blockResults.filter { $0.type == .congruent && $0.responseCorrect }.compactMap(\.reactionTime)) ?? 0
        let incongruentRT = timeAverage(blockResults.filter { $0.type == .incongruent && $0.responseCorrect }.compactMap(\.reactionTime)) ?? 0
        let speedScore = clamp((1_200 - incongruentRT * 1_000) / 780)
        let conflictScore = clamp((220 - max(0, (incongruentRT - congruentRT) * 1_000)) / 180)
        let performanceIndex = clamp(0.45 * accuracy + 0.35 * speedScore + 0.20 * conflictScore)
        
        // We defer to continuous staircase for true level, this outcome is just UI sugar
        let diff = currentLevel - blockLevelHistory.last!
        let outcome: AdaptiveBlockOutcome = diff > 0 ? .promote : (diff < 0 ? .demote : .stay)
        return (outcome, currentLevel, performanceIndex)
    }

    private func generateSingleTrial(spec: FlankerLevelSpec, startId: Int) -> FlankerTrial {
        let isCongruent = Double.random(in: 0...1) > spec.incongruentRatio
        let targetDir: FlankerDirection = Bool.random() ? .left : .right
        let flankerDir = isCongruent ? targetDir : (targetDir == .left ? .right : .left)
        return FlankerTrial(
            id: startId,
            type: isCongruent ? .congruent : .incongruent,
            targetDirection: targetDir,
            flankerDirection: flankerDir
        )
    }
}

private func timeAverage(_ values: [TimeInterval]) -> TimeInterval? {
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +) / Double(values.count)
}

private func clamp(_ value: Double) -> Double {
    min(max(value, 0), 1)
}

// MARK: - Core Adaptive Engine Protocol & Math

public enum AdaptiveStaircaseRule {
    case threeUpOneDown
    case twoUpOneDown
    case oneUpOneDown
}

public class AdaptiveStaircase {
    private let rule: AdaptiveStaircaseRule
    private let minLevel: Int
    private let maxLevel: Int
    
    private var consecutiveCorrects: Int = 0
    private var consecutiveIncorrects: Int = 0
    
    public private(set) var currentLevel: Int
    
    public init(startLevel: Int, minLevel: Int = 1, maxLevel: Int, rule: AdaptiveStaircaseRule = .threeUpOneDown) {
        self.currentLevel = max(minLevel, min(startLevel, maxLevel))
        self.minLevel = minLevel
        self.maxLevel = maxLevel
        self.rule = rule
    }
    
    @discardableResult
    public func recordTrial(correct: Bool) -> Int {
        if correct {
            consecutiveCorrects += 1
            consecutiveIncorrects = 0
            
            let threshold: Int
            switch rule {
            case .threeUpOneDown: threshold = 3
            case .twoUpOneDown: threshold = 2
            case .oneUpOneDown: threshold = 1
            }
            
            if consecutiveCorrects >= threshold {
                consecutiveCorrects = 0
                return advanceLevel()
            }
        } else {
            consecutiveIncorrects += 1
            consecutiveCorrects = 0
            
            consecutiveIncorrects = 0
            return dropLevel()
        }
        return 0
    }
    
    private func advanceLevel() -> Int {
        if currentLevel < maxLevel {
            currentLevel += 1
            return 1
        }
        return 0
    }
    
    private func dropLevel() -> Int {
        if currentLevel > minLevel {
            currentLevel -= 1
            return -1
        }
        return 0
    }
}
