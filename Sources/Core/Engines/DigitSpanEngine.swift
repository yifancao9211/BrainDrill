import Foundation
import Observation

@Observable
final class DigitSpanEngine {
    let config: DigitSpanSessionConfig
    let startedAt: Date

    private(set) var phase: Phase = .idle
    private(set) var currentTrial: DigitSpanTrial?
    private(set) var currentLength: Int
    private(set) var trialIndex: Int = 0
    private(set) var results: [DigitSpanTrialResult] = []
    private(set) var presentingDigitIndex: Int = 0
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

    init(config: DigitSpanSessionConfig, startedAt: Date = Date()) {
        self.config = config
        self.startedAt = startedAt
        self.currentLength = min(max(config.startingLength, config.minLength), config.maxLength)
    }

    func beginNextTrial() {
        let sequence = generateSequence(length: currentLength)
        currentTrial = DigitSpanTrial(id: trialIndex, sequence: sequence, mode: config.mode)
        presentingDigitIndex = 0
        phase = .presenting
    }

    func advancePresentingDigit() -> Bool {
        guard let trial = currentTrial else { return false }
        presentingDigitIndex += 1
        return presentingDigitIndex < trial.length
    }

    func finishPresenting() {
        phase = .recalling
    }

    func submitResponse(_ userInput: [Int]) -> DigitSpanTrialResult {
        guard let trial = currentTrial else {
            fatalError("No active trial")
        }

        let result = DigitSpanTrialResult(trial: trial, userInput: userInput)
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

    func computeMetrics() -> DigitSpanMetrics {
        let forwardResults = results.filter { $0.mode == .forward }
        let backwardResults = results.filter { $0.mode == .backward }

        let maxFwd = forwardResults.filter(\.correct).map(\.spanLength).max() ?? 0
        let maxBwd = backwardResults.filter(\.correct).map(\.spanLength).max() ?? 0

        let correctCount = results.filter(\.correct).count
        let totalErrors = results.reduce(0) { $0 + $1.positionErrors }

        return DigitSpanMetrics(
            maxSpanForward: config.mode == .forward ? max(maxFwd, maxSpanReached) : maxFwd,
            maxSpanBackward: config.mode == .backward ? max(maxBwd, maxSpanReached) : maxBwd,
            thresholdSpan: thresholdSpanEstimate,
            reversalCount: reversals.count,
            totalTrials: results.count,
            correctTrials: correctCount,
            accuracy: results.isEmpty ? 0 : Double(correctCount) / Double(results.count),
            positionErrors: totalErrors
        )
    }

    private func generateSequence(length: Int) -> [Int] {
        var seq: [Int] = []
        for _ in 0..<length {
            var digit: Int
            repeat {
                digit = Int.random(in: 0...9)
            } while digit == seq.last
            seq.append(digit)
        }
        return seq
    }
}
