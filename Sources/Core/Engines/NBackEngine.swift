import Foundation
import Observation

/// Standard auto-paced single-key N-Back (Jaeggi-style).
///
/// Stimuli play automatically one at a time: each digit is shown for
/// `currentStimulusDurationMs`, followed by a blank inter-stimulus interval of
/// `currentISIMs`. The participant presses "match" only when the current digit
/// equals the one N positions back; non-targets require no response. The first
/// N stimuli of every block have no possible target and are observation-only.
@Observable
final class NBackEngine {
    let config: NBackSessionConfig
    let startedAt: Date

    private(set) var currentN: Int
    private(set) var currentStimulusDurationMs: Int
    private(set) var currentISIMs: Int
    private(set) var currentBlock: Int = 0
    private(set) var currentTrialIndex: Int = 0
    private(set) var sequence: [Int] = []
    private(set) var results: [NBackTrialResult] = []
    private(set) var phase: Phase = .idle
    private(set) var stimulusOnsetTime: Date?
    private(set) var respondedThisTrial: Bool = false
    /// True while the leading, unscored warm-up block is playing.
    private(set) var isPractice: Bool = false
    private var responseTimeThisTrial: TimeInterval?
    private var slowDownNextBlock: Bool = false

    enum Phase: Equatable, Hashable {
        case idle
        case stimulus
        case isi
        case practiceComplete
        case blockBreak(blockIndex: Int, nextN: Int)
        case completed
    }

    var currentStimulus: Int? {
        guard currentTrialIndex < sequence.count else { return nil }
        return sequence[currentTrialIndex]
    }

    /// Whether the current trial is a target (current digit == digit N steps back).
    var isTarget: Bool {
        guard currentTrialIndex >= currentN, currentTrialIndex < sequence.count else { return false }
        return sequence[currentTrialIndex] == sequence[currentTrialIndex - currentN]
    }

    /// True while the current digit is part of the leading N-digit memory build-up,
    /// where no response is possible yet.
    var isObservationOnly: Bool {
        currentTrialIndex < currentN
    }

    var trialsInCurrentBlock: Int {
        config.trialsPerBlock + currentN
    }

    var trialInBlock: Int {
        currentTrialIndex - (currentBlock * trialsInCurrentBlock)
    }

    var completionFraction: Double {
        guard !isPractice else { return 0 }
        let totalTrials = config.blockCount * trialsInCurrentBlock
        guard totalTrials > 0 else { return 0 }
        return Double(currentBlock * trialsInCurrentBlock + currentTrialIndex % trialsInCurrentBlock) / Double(totalTrials)
    }

    var isComplete: Bool { phase == .completed }

    private var absoluteTrialIndex: Int {
        currentBlock * trialsInCurrentBlock + currentTrialIndex
    }

    init(config: NBackSessionConfig, startedAt: Date = Date()) {
        self.config = config
        self.startedAt = startedAt
        self.currentN = config.startingN
        let timing = AdaptiveScoring.nBackTiming(level: config.startingN, internalSkillScore: config.internalSkillScore, slowDownAfterPoorBlock: false)
        self.currentStimulusDurationMs = timing.stimulusMs
        self.currentISIMs = timing.isiMs
        self.isPractice = config.practiceTrials > 0
        let leadingTrials = isPractice ? config.practiceTrials : config.trialsPerBlock
        self.sequence = Self.generateSequence(config: config, n: config.startingN, trials: leadingTrials)
    }

    // MARK: - Auto-paced flow

    /// Begin the first/next trial of the current block (called when phase is `.idle`).
    func beginTrial(at date: Date = Date()) {
        showStimulus(at: date)
    }

    func showStimulus(at date: Date = Date()) {
        phase = .stimulus
        stimulusOnsetTime = date
        respondedThisTrial = false
        responseTimeThisTrial = nil
    }

    /// Stimulus is hidden; the response window remains open through the blank ISI.
    func enterISI() {
        guard phase == .stimulus else { return }
        phase = .isi
    }

    /// Record a single "match" response for the current trial. A non-response means
    /// the participant judged the digit as a non-match.
    func recordMatch(at date: Date) {
        guard phase == .stimulus || phase == .isi else { return }
        guard !respondedThisTrial, currentTrialIndex >= currentN else { return }
        respondedThisTrial = true
        responseTimeThisTrial = stimulusOnsetTime.map { date.timeIntervalSince($0) }
    }

    /// Close the current trial, score it, and either present the next digit, take a
    /// block break, or finish the session.
    func advanceTrial(at date: Date = Date()) {
        finishCurrentTrialIfNeeded(at: date)
        currentTrialIndex += 1

        if currentTrialIndex >= sequence.count {
            // End of the warm-up block: switch to the first scored block (same N).
            if isPractice {
                isPractice = false
                currentTrialIndex = 0
                sequence = Self.generateSequence(config: config, n: currentN, trials: config.trialsPerBlock)
                phase = .practiceComplete
                return
            }

            let blockAccuracy = computeBlockAccuracy()
            let (blockHitRate, blockFalseAlarmRate) = computeRecentBlockSignal()

            currentBlock += 1
            if currentBlock >= config.blockCount {
                phase = .completed
                return
            }

            // 准确率把「非目标不按」也算对，30% 目标比例下全程不按手就有 70% 准确率，
            // 永远跌不破降档线——所以降档还要看命中率：目标漏掉一半以上同样降 N。
            var nextN = currentN
            if blockAccuracy >= config.promoteThreshold && currentN < config.maxN {
                nextN = currentN + 1
            } else if (blockAccuracy < config.demoteThreshold || blockHitRate < 0.5) && currentN > 1 {
                nextN = currentN - 1
            }

            slowDownNextBlock = blockHitRate < 0.65 || blockFalseAlarmRate > 0.30
            phase = .blockBreak(blockIndex: currentBlock, nextN: nextN)
        } else {
            showStimulus(at: date)
        }
    }

    func startNextBlock(n: Int) {
        currentN = n
        currentTrialIndex = 0
        sequence = Self.generateSequence(config: config, n: n, trials: config.trialsPerBlock)
        let timing = AdaptiveScoring.nBackTiming(level: n, internalSkillScore: config.internalSkillScore, slowDownAfterPoorBlock: slowDownNextBlock)
        currentStimulusDurationMs = timing.stimulusMs
        currentISIMs = timing.isiMs
        slowDownNextBlock = false
        phase = .idle
    }

    // MARK: - Metrics

    func computeMetrics() -> NBackMetrics {
        let targets = results.filter(\.isTarget)
        let nonTargets = results.filter { !$0.isTarget }

        let hits = targets.filter(\.responded).count
        let hitRate = targets.isEmpty ? 0 : Double(hits) / Double(targets.count)
        let falseAlarms = nonTargets.filter(\.responded).count
        let faRate = nonTargets.isEmpty ? 0 : Double(falseAlarms) / Double(nonTargets.count)

        let hr = min(max(hitRate, 0.01), 0.99)
        let fa = min(max(faRate, 0.01), 0.99)
        let dPrime = Self.zScore(hr) - Self.zScore(fa)
        // Mean reaction time over responded trials (auto-paced: a fixed-pace
        // "decision interval" is not meaningful, so report response speed instead).
        let averageDecisionInterval = results.compactMap(\.reactionTime).average ?? 0

        return NBackMetrics(
            nLevel: currentN,
            totalTrials: results.count,
            hitRate: hitRate,
            falseAlarmRate: faRate,
            dPrime: dPrime,
            averageDecisionInterval: averageDecisionInterval
        )
    }

    private func computeBlockAccuracy() -> Double {
        let blockResults = Array(results.suffix(config.trialsPerBlock))
        guard !blockResults.isEmpty else { return 0 }

        let correct = blockResults.filter { result in
            if result.isTarget { return result.responded }
            return !result.responded
        }
        return Double(correct.count) / Double(blockResults.count)
    }

    private func computeRecentBlockSignal() -> (hitRate: Double, falseAlarmRate: Double) {
        let blockResults = Array(results.suffix(config.trialsPerBlock))
        let targets = blockResults.filter(\.isTarget)
        let nonTargets = blockResults.filter { !$0.isTarget }

        let hitRate = targets.isEmpty ? 0 : Double(targets.filter(\.responded).count) / Double(targets.count)
        let falseAlarmRate = nonTargets.isEmpty ? 0 : Double(nonTargets.filter(\.responded).count) / Double(nonTargets.count)
        return (hitRate, falseAlarmRate)
    }

    private func finishCurrentTrialIfNeeded(at date: Date) {
        guard !isPractice else { return } // warm-up trials are not scored
        guard currentTrialIndex >= currentN, currentTrialIndex < sequence.count else { return }
        guard !results.contains(where: { $0.trialIndex == absoluteTrialIndex }) else { return }

        let result = NBackTrialResult(
            trialIndex: absoluteTrialIndex,
            isTarget: isTarget,
            responded: respondedThisTrial,
            reactionTime: responseTimeThisTrial,
            decisionInterval: responseTimeThisTrial
        )
        results.append(result)
    }

    private static func zScore(_ p: Double) -> Double {
        let clamped = min(max(p, 0.0001), 0.9999)
        let t = sqrt(-2.0 * log(clamped < 0.5 ? clamped : 1.0 - clamped))
        let c0 = 2.515517, c1 = 0.802853, c2 = 0.010328
        let d1 = 1.432788, d2 = 0.189269, d3 = 0.001308
        let z = t - (c0 + c1 * t + c2 * t * t) / (1.0 + d1 * t + d2 * t * t + d3 * t * t * t)
        return clamped < 0.5 ? -z : z
    }

    private static func generateSequence(config: NBackSessionConfig, n: Int, trials: Int) -> [Int] {
        let total = trials + n
        let targetCount = Int(Double(trials) * config.targetRatio)
        var sequence: [Int] = []

        for i in 0..<total {
            if i < n {
                sequence.append(Int.random(in: config.stimulusRange))
            } else {
                let shouldBeTarget = sequence.count - n < trials &&
                    (total - i <= targetCount - countTargets(in: sequence, n: n) ||
                     (Bool.random() && countTargets(in: sequence, n: n) < targetCount))

                if shouldBeTarget && countTargets(in: sequence, n: n) < targetCount {
                    sequence.append(sequence[i - n])
                } else {
                    var val: Int
                    repeat {
                        val = Int.random(in: config.stimulusRange)
                    } while val == sequence[i - n]
                    sequence.append(val)
                }
            }
        }
        return sequence
    }

    private static func countTargets(in sequence: [Int], n: Int) -> Int {
        guard sequence.count > n else { return 0 }
        var count = 0
        for i in n..<sequence.count {
            if sequence[i] == sequence[i - n] { count += 1 }
        }
        return count
    }
}
