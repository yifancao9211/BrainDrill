import Foundation
import Observation

@Observable
final class CorsiBlockEngine {
    let config: CorsiBlockSessionConfig
    let startedAt: Date

    private(set) var phase: Phase = .idle
    private(set) var currentTrial: CorsiBlockTrial?
    private(set) var currentLength: Int
    private(set) var trialIndex: Int = 0
    private(set) var results: [CorsiBlockTrialResult] = []
    private(set) var presentingBlockIndex: Int = 0
    private(set) var maxSpanReached: Int = 0
    /// 每次方向反转时记录被测的广度（峰/谷），用于阈值估计与结束判定。
    private(set) var reversals: [Int] = []

    /// 上一步的阶梯方向：+1 升档、-1 降档、0 尚无。
    private var lastDirection: Int = 0

    enum Phase: Equatable, Hashable {
        case idle
        case presenting
        case recalling
        case feedback(correct: Bool)
        case completed
    }

    var isComplete: Bool { phase == .completed }

    var reversalCount: Int { reversals.count }

    var reversalsTarget: Int { config.reversalsToComplete }

    /// 实时阶梯阈值估计（反转点均值，丢弃前若干次预热反转）。
    var thresholdSpanEstimate: Double {
        Self.threshold(from: reversals, fallback: maxSpanReached)
    }

    static func threshold(from reversals: [Int], fallback: Int) -> Double {
        guard !reversals.isEmpty else { return Double(fallback) }
        // 反转足够多时丢弃前两次预热反转，降低起步广度带来的偏差。
        let drop = reversals.count >= 4 ? 2 : 0
        let used = Array(reversals.dropFirst(drop))
        return Double(used.reduce(0, +)) / Double(used.count)
    }

    init(config: CorsiBlockSessionConfig, startedAt: Date = Date()) {
        self.config = config
        self.startedAt = startedAt
        self.currentLength = min(max(config.startingLength, config.minLength), config.maxLength)
    }

    func beginNextTrial() {
        let sequence = generateSequence(length: currentLength)
        currentTrial = CorsiBlockTrial(id: trialIndex, sequence: sequence, mode: config.mode)
        presentingBlockIndex = 0
        phase = .presenting
    }

    func advancePresentingBlock() -> Bool {
        guard let trial = currentTrial else { return false }
        presentingBlockIndex += 1
        return presentingBlockIndex < trial.length
    }

    func finishPresenting() {
        phase = .recalling
    }

    func submitResponse(_ userInput: [Int]) -> CorsiBlockTrialResult {
        guard let trial = currentTrial else {
            fatalError("No active trial")
        }

        let result = CorsiBlockTrialResult(trial: trial, userInput: userInput)
        results.append(result)

        if result.correct {
            maxSpanReached = max(maxSpanReached, currentLength)
        }

        phase = .feedback(correct: result.correct)
        return result
    }

    func advanceAfterFeedback() {
        trialIndex += 1

        guard let last = results.last else {
            beginNextTrial()
            return
        }

        // 1-up / 1-down 阶梯：答对升一档、答错降一档。
        let direction = last.correct ? 1 : -1

        // 方向相对上一步发生改变即为一次反转，记录当前（调整前）广度作为峰/谷。
        if lastDirection != 0 && direction != lastDirection {
            reversals.append(currentLength)
        }
        lastDirection = direction

        // 满反转数或达到安全试次上限则结束本局。
        if reversals.count >= config.reversalsToComplete || trialIndex >= config.maxTrials {
            phase = .completed
            return
        }

        currentLength = min(max(currentLength + direction, config.minLength), config.maxLength)
        beginNextTrial()
    }

    func computeMetrics() -> CorsiBlockMetrics {
        let correctCount = results.filter(\.correct).count
        let totalErrors = results.reduce(0) { $0 + $1.positionErrors }

        return CorsiBlockMetrics(
            maxSpan: maxSpanReached,
            thresholdSpan: thresholdSpanEstimate,
            reversalCount: reversals.count,
            totalTrials: results.count,
            correctTrials: correctCount,
            accuracy: results.isEmpty ? 0 : Double(correctCount) / Double(results.count),
            positionErrors: totalErrors,
            mode: config.mode
        )
    }

    private func generateSequence(length: Int) -> [Int] {
        Array((0..<config.gridSize).shuffled().prefix(length))
    }
}
