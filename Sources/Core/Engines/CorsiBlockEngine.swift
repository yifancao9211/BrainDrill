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

    private var consecutiveCorrect: Int = 0
    private var consecutiveWrong: Int = 0

    enum Phase: Equatable, Hashable {
        case idle
        case presenting
        case recalling
        case feedback(correct: Bool)
        case completed
    }

    var isComplete: Bool { phase == .completed }

    var consecutiveCorrectCount: Int { consecutiveCorrect }

    var consecutiveWrongCount: Int { consecutiveWrong }

    var advanceThreshold: Int { config.consecutiveCorrectToAdvance }

    var endThreshold: Int { config.consecutiveWrongToDemote }

    var completionFraction: Double {
        guard !results.isEmpty else { return 0 }
        return Double(results.count) / Double(results.count + 3)
    }

    init(config: CorsiBlockSessionConfig, startedAt: Date = Date()) {
        self.config = config
        self.startedAt = startedAt
        self.currentLength = config.startingLength
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

    func computeMetrics() -> CorsiBlockMetrics {
        let correctCount = results.filter(\.correct).count
        let totalErrors = results.reduce(0) { $0 + $1.positionErrors }

        return CorsiBlockMetrics(
            maxSpan: maxSpanReached,
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
