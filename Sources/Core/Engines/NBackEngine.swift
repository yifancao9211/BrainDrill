import Foundation
import Observation

@Observable
final class NBackEngine {
    let config: NBackSessionConfig
    let startedAt: Date

    private(set) var currentN: Int
    private(set) var currentBlock: Int = 0
    private(set) var currentTrialIndex: Int = 0
    private(set) var sequence: [Int] = []
    private(set) var results: [NBackTrialResult] = []
    private(set) var phase: Phase = .idle
    private(set) var stimulusOnsetTime: Date?
    private(set) var respondedThisTrial: Bool = false

    enum Phase: Equatable {
        case idle
        case stimulus
        case isi
        case blockBreak(blockIndex: Int, nextN: Int)
        case completed
    }

    var currentStimulus: Int? {
        guard currentTrialIndex < sequence.count else { return nil }
        return sequence[currentTrialIndex]
    }

    var isTarget: Bool {
        guard currentTrialIndex >= currentN, currentTrialIndex < sequence.count else { return false }
        return sequence[currentTrialIndex] == sequence[currentTrialIndex - currentN]
    }

    var trialsInCurrentBlock: Int {
        config.trialsPerBlock + currentN
    }

    var trialInBlock: Int {
        currentTrialIndex - (currentBlock * trialsInCurrentBlock)
    }

    var completionFraction: Double {
        let totalTrials = config.blockCount * trialsInCurrentBlock
        return Double(currentBlock * trialsInCurrentBlock + currentTrialIndex % trialsInCurrentBlock) / Double(totalTrials)
    }

    var isComplete: Bool { phase == .completed }

    init(config: NBackSessionConfig, startedAt: Date = Date()) {
        self.config = config
        self.startedAt = startedAt
        self.currentN = config.startingN
        self.sequence = Self.generateSequence(config: config, n: config.startingN)
    }

    func showStimulus() {
        phase = .stimulus
        stimulusOnsetTime = Date()
        respondedThisTrial = false
    }

    func enterISI() {
        if !respondedThisTrial && currentTrialIndex >= currentN {
            let result = NBackTrialResult(
                trialIndex: currentTrialIndex,
                isTarget: isTarget,
                responded: false,
                reactionTime: nil
            )
            results.append(result)
        }
        phase = .isi
    }

    func recordMatch(at date: Date) -> NBackTrialResult? {
        guard phase == .stimulus || phase == .isi, !respondedThisTrial, currentTrialIndex >= currentN else { return nil }
        respondedThisTrial = true
        let rt = stimulusOnsetTime.map { date.timeIntervalSince($0) }
        let result = NBackTrialResult(
            trialIndex: currentTrialIndex,
            isTarget: isTarget,
            responded: true,
            reactionTime: rt
        )
        results.append(result)
        return result
    }

    func advanceToNext() {
        currentTrialIndex += 1

        if currentTrialIndex >= sequence.count {
            let blockAccuracy = computeBlockAccuracy()

            currentBlock += 1
            if currentBlock >= config.blockCount {
                phase = .completed
                return
            }

            var nextN = currentN
            if blockAccuracy >= config.promoteThreshold && currentN < config.maxN {
                nextN = currentN + 1
            } else if blockAccuracy < config.demoteThreshold && currentN > 1 {
                nextN = currentN - 1
            }

            phase = .blockBreak(blockIndex: currentBlock, nextN: nextN)
        } else {
            phase = .idle
        }
    }

    func startNextBlock(n: Int) {
        currentN = n
        currentTrialIndex = 0
        sequence = Self.generateSequence(config: config, n: n)
        phase = .idle
    }

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

        return NBackMetrics(
            nLevel: currentN,
            totalTrials: results.count,
            hitRate: hitRate,
            falseAlarmRate: faRate,
            dPrime: dPrime
        )
    }

    private func computeBlockAccuracy() -> Double {
        let blockStart = currentBlock * trialsInCurrentBlock + currentN
        let blockResults = results.filter { $0.trialIndex >= blockStart }
        guard !blockResults.isEmpty else { return 0 }

        let correct = blockResults.filter { result in
            if result.isTarget { return result.responded }
            return !result.responded
        }
        return Double(correct.count) / Double(blockResults.count)
    }

    private static func zScore(_ p: Double) -> Double {
        let clamped = min(max(p, 0.0001), 0.9999)
        let t = sqrt(-2.0 * log(clamped < 0.5 ? clamped : 1.0 - clamped))
        let c0 = 2.515517, c1 = 0.802853, c2 = 0.010328
        let d1 = 1.432788, d2 = 0.189269, d3 = 0.001308
        let z = t - (c0 + c1 * t + c2 * t * t) / (1.0 + d1 * t + d2 * t * t + d3 * t * t * t)
        return clamped < 0.5 ? -z : z
    }

    private static func generateSequence(config: NBackSessionConfig, n: Int) -> [Int] {
        let total = config.trialsPerBlock + n
        let targetCount = Int(Double(config.trialsPerBlock) * config.targetRatio)
        var sequence: [Int] = []

        for i in 0..<total {
            if i < n {
                sequence.append(Int.random(in: config.stimulusRange))
            } else {
                let shouldBeTarget = sequence.count - n < config.trialsPerBlock &&
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
