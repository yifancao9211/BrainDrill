import Foundation
import Observation

@Observable
final class ChangeDetectionEngine {
    let config: ChangeDetectionSessionConfig
    let startedAt: Date

    private(set) var currentTrialIndex: Int = 0
    private(set) var results: [ChangeDetectionTrialResult] = []
    private(set) var phase: Phase = .idle
    private(set) var currentTrial: ChangeDetectionTrial?
    private(set) var currentSetSize: Int
    private(set) var probeOnsetTime: Date?

    private var consecutiveCorrect: Int = 0
    private var consecutiveWrong: Int = 0
    private var totalTrials: Int

    enum Phase: Equatable, Hashable {
        case idle
        case encoding
        case retention
        case probe
        case feedback(correct: Bool)
        case iti
        case completed
    }

    var completionFraction: Double {
        Double(currentTrialIndex) / Double(totalTrials)
    }

    var isComplete: Bool { phase == .completed }

    init(config: ChangeDetectionSessionConfig, startedAt: Date = Date()) {
        self.config = config
        self.startedAt = startedAt
        self.currentSetSize = config.initialSetSize
        self.totalTrials = config.trialsPerBlock * config.blockCount
    }

    func beginTrial() {
        currentTrial = generateTrial()
        phase = .encoding
    }

    func startRetention() {
        phase = .retention
    }

    func showProbe() {
        phase = .probe
        probeOnsetTime = Date()
    }

    func recordResponse(userSaidChanged: Bool, at date: Date = Date()) -> ChangeDetectionTrialResult? {
        guard let trial = currentTrial, phase == .probe else { return nil }
        let rt = probeOnsetTime.map { date.timeIntervalSince($0) }
        let result = ChangeDetectionTrialResult(trial: trial, userSaidChanged: userSaidChanged, reactionTime: rt)
        results.append(result)

        if result.correct {
            consecutiveCorrect += 1
            consecutiveWrong = 0
        } else {
            consecutiveWrong += 1
            consecutiveCorrect = 0
        }

        if consecutiveCorrect >= config.consecutiveCorrectToAdvance && currentSetSize < config.maxSetSize {
            currentSetSize += 1
            consecutiveCorrect = 0
        } else if consecutiveWrong >= config.consecutiveWrongToDemote && currentSetSize > 1 {
            currentSetSize -= 1
            consecutiveWrong = 0
        }

        phase = .feedback(correct: result.correct)
        return result
    }

    func advanceToNext() {
        currentTrialIndex += 1
        if currentTrialIndex >= totalTrials {
            phase = .completed
        } else {
            phase = .iti
        }
    }

    func computeMetrics() -> ChangeDetectionMetrics {
        let hits = results.filter(\.isHit).count
        let misses = results.filter(\.isMiss).count
        let falseAlarms = results.filter(\.isFalseAlarm).count
        let correctRejections = results.filter(\.isCorrectRejection).count

        let signalTrials = hits + misses
        let noiseTrials = falseAlarms + correctRejections
        let hitRate = signalTrials > 0 ? Double(hits) / Double(signalTrials) : 0
        let faRate = noiseTrials > 0 ? Double(falseAlarms) / Double(noiseTrials) : 0
        let dp = MetricsCalculator.dPrime(hitRate: hitRate, falseAlarmRate: faRate)

        let correctCount = results.filter(\.correct).count
        let accuracy = results.isEmpty ? 0 : Double(correctCount) / Double(results.count)

        let rts = results.compactMap(\.reactionTime)
        let avgRT = rts.isEmpty ? 0 : rts.reduce(0, +) / Double(rts.count)

        let maxSS = results.map(\.setSize).max() ?? config.initialSetSize

        return ChangeDetectionMetrics(
            totalTrials: results.count,
            accuracy: accuracy,
            dPrime: dp,
            hitRate: hitRate,
            falseAlarmRate: faRate,
            maxSetSize: maxSS,
            averageRT: avgRT
        )
    }

    private func generateTrial() -> ChangeDetectionTrial {
        let positions = generatePositions(count: currentSetSize)
        let colorCount = ChangeDetectionSessionConfig.availableColors
        var usedColors: Set<Int> = []
        var colors: [Int] = []
        for _ in 0..<currentSetSize {
            var c: Int
            repeat {
                c = Int.random(in: 0..<colorCount)
            } while usedColors.contains(c)
            usedColors.insert(c)
            colors.append(c)
        }

        let shouldChange = Double.random(in: 0...1) < config.changeRatio
        let changedIndex: Int?
        let changedColor: Int?

        if shouldChange {
            let idx = Int.random(in: 0..<currentSetSize)
            var newColor: Int
            repeat {
                newColor = Int.random(in: 0..<colorCount)
            } while newColor == colors[idx]
            changedIndex = idx
            changedColor = newColor
        } else {
            changedIndex = nil
            changedColor = nil
        }

        return ChangeDetectionTrial(
            id: currentTrialIndex,
            originalColors: colors,
            positions: positions,
            changedIndex: changedIndex,
            changedColor: changedColor,
            setSize: currentSetSize
        )
    }

    private func generatePositions(count: Int) -> [CGPoint] {
        var positions: [CGPoint] = []
        let gridSize = 4
        var available: [(Int, Int)] = []
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                available.append((row, col))
            }
        }
        available.shuffle()

        let cellSize = 1.0 / Double(gridSize)
        for i in 0..<min(count, available.count) {
            let (row, col) = available[i]
            let x = (Double(col) + 0.5) * cellSize
            let y = (Double(row) + 0.5) * cellSize
            positions.append(CGPoint(x: x, y: y))
        }
        return positions
    }
}
