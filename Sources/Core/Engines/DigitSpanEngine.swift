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

    private var consecutiveCorrect: Int = 0
    private var consecutiveWrong: Int = 0

    enum Phase: Equatable {
        case idle
        case presenting
        case recalling
        case feedback(correct: Bool)
        case completed
    }

    var isComplete: Bool { phase == .completed }

    var completionFraction: Double {
        guard !results.isEmpty else { return 0 }
        return Double(results.count) / Double(results.count + 3)
    }

    init(config: DigitSpanSessionConfig, startedAt: Date = Date()) {
        self.config = config
        self.startedAt = startedAt
        self.currentLength = config.startingLength
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
            consecutiveCorrect += 1
            consecutiveWrong = 0
            maxSpanReached = max(maxSpanReached, currentLength)
        } else {
            consecutiveWrong += 1
            consecutiveCorrect = 0
        }

        phase = .feedback(correct: result.correct)
        return result
    }

    func advanceAfterFeedback() {
        trialIndex += 1

        if consecutiveCorrect >= config.consecutiveCorrectToAdvance {
            consecutiveCorrect = 0
            if currentLength < config.maxLength {
                currentLength += 1
            }
        }

        if consecutiveWrong >= config.consecutiveWrongToDemote {
            phase = .completed
            return
        }

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
