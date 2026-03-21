import Foundation
import Observation

@Observable
final class StopSignalEngine {
    let config: StopSignalSessionConfig
    let trials: [StopSignalTrial]
    let startedAt: Date

    private(set) var currentTrialIndex: Int = 0
    private(set) var results: [StopSignalTrialResult] = []
    private(set) var phase: Phase = .idle
    private(set) var stimulusOnsetTime: Date?
    private(set) var currentSSD: Int

    enum Phase: Equatable, Hashable {
        case idle
        case fixation
        case stimulus
        case stopSignalShown
        case feedback(correct: Bool)
        case iti
        case completed
    }

    var currentTrial: StopSignalTrial? {
        guard currentTrialIndex < trials.count else { return nil }
        return trials[currentTrialIndex]
    }

    var completionFraction: Double {
        Double(currentTrialIndex) / Double(trials.count)
    }

    var isComplete: Bool { phase == .completed }

    init(config: StopSignalSessionConfig, startedAt: Date = Date()) {
        self.config = config
        self.startedAt = startedAt
        self.currentSSD = config.initialSSD
        self.trials = Self.generateTrials(config: config)
    }

    func beginTrial() {
        phase = .fixation
    }

    func showStimulus() {
        phase = .stimulus
        stimulusOnsetTime = Date()
    }

    func showStopSignal() {
        phase = .stopSignalShown
    }

    func recordResponse(_ direction: StopSignalDirection, at date: Date = Date()) -> StopSignalTrialResult? {
        guard let trial = currentTrial,
              phase == .stimulus || phase == .stopSignalShown else { return nil }

        let rt = stimulusOnsetTime.map { date.timeIntervalSince($0) }
        let ssd = trial.hasStopSignal ? currentSSD : nil
        let result = StopSignalTrialResult(trial: trial, responseDirection: direction, reactionTime: rt, stopSignalDelay: ssd)
        results.append(result)

        if trial.hasStopSignal {
            currentSSD = max(50, currentSSD - config.ssdStepMs)
        }

        phase = .feedback(correct: result.correct)
        return result
    }

    func recordStopTimeout() {
        guard let trial = currentTrial else { return }
        let ssd = trial.hasStopSignal ? currentSSD : nil
        let result = StopSignalTrialResult(trial: trial, responseDirection: nil, reactionTime: nil, stopSignalDelay: ssd)
        results.append(result)

        if trial.hasStopSignal {
            currentSSD += config.ssdStepMs
        }

        phase = .feedback(correct: result.correct)
    }

    func recordGoTimeout() {
        guard let trial = currentTrial, !trial.hasStopSignal else { return }
        let result = StopSignalTrialResult(trial: trial, responseDirection: nil, reactionTime: nil, stopSignalDelay: nil)
        results.append(result)
        phase = .feedback(correct: false)
    }

    func advanceToNext() {
        currentTrialIndex += 1
        if currentTrialIndex >= trials.count {
            phase = .completed
        } else {
            phase = .iti
        }
    }

    func randomITI() -> Int {
        Int.random(in: config.itiRangeMs)
    }

    func computeMetrics() -> StopSignalMetrics {
        let goTrials = results.filter { !$0.hasStopSignal }
        let stopTrials = results.filter { $0.hasStopSignal }

        let goCorrect = goTrials.filter(\.correct)
        let goRTs = goCorrect.compactMap(\.reactionTime).sorted()
        let goRT = goRTs.isEmpty ? 0 : MetricsCalculator.medianRT(goRTs)
        let goAccuracy = goTrials.isEmpty ? 0 : Double(goCorrect.count) / Double(goTrials.count)

        let inhibited = stopTrials.filter(\.inhibited).count
        let inhibitionRate = stopTrials.isEmpty ? 0 : Double(inhibited) / Double(stopTrials.count)

        let avgSSD = stopTrials.compactMap(\.stopSignalDelay).map(Double.init)
        let meanSSD = avgSSD.isEmpty ? 0 : avgSSD.reduce(0, +) / Double(avgSSD.count)

        // SSRT = median Go RT - mean SSD (integration method approximation)
        let ssrt = max(0, goRT - meanSSD / 1000.0)

        return StopSignalMetrics(
            totalTrials: results.count,
            goRT: goRT,
            goAccuracy: goAccuracy,
            inhibitionRate: inhibitionRate,
            ssrt: ssrt,
            meanSSD: meanSSD
        )
    }

    private static func generateTrials(config: StopSignalSessionConfig) -> [StopSignalTrial] {
        let total = config.trialsPerBlock * config.blockCount
        let stopCount = Int(Double(total) * config.stopRatio)

        var types: [Bool] = Array(repeating: true, count: stopCount) + Array(repeating: false, count: total - stopCount)
        types.shuffle()

        return types.enumerated().map { i, isStop in
            StopSignalTrial(
                id: i,
                correctDirection: Bool.random() ? .left : .right,
                hasStopSignal: isStop
            )
        }
    }
}
