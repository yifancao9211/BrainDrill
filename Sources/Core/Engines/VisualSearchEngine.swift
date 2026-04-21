import Foundation
import Observation

@Observable
final class VisualSearchEngine {
    let config: VisualSearchSessionConfig
    let target: VisualSearchTarget
    let startedAt: Date

    private(set) var trials: [VisualSearchTrial] = []
    private(set) var currentLevel: Int
    private(set) var currentBlockIndex: Int = 0
    private(set) var currentSpec: VisualSearchLevelSpec
    private(set) var blockLevelHistory: [Int] = []
    private(set) var blockOutcomes: [AdaptiveBlockOutcome] = []
    private(set) var lastBlockOutcome: AdaptiveBlockOutcome?
    private(set) var lastBlockPerformanceIndex: Double?
    private(set) var currentTrialIndex: Int = 0
    private(set) var currentBlockStartIndex: Int = 0
    private(set) var currentBlockTrialCount: Int
    private(set) var results: [VisualSearchTrialResult] = []
    private(set) var phase: Phase = .idle
    private(set) var displayOnsetTime: Date?

    enum Phase: Equatable, Hashable {
        case idle
        case fixation
        case display
        case feedback(correct: Bool)
        case iti
        case blockBreak(blockIndex: Int, outcome: AdaptiveBlockOutcome, nextLevel: Int)
        case completed
    }

    var currentTrial: VisualSearchTrial? {
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

    init(config: VisualSearchSessionConfig, startedAt: Date = Date()) {
        self.config = config
        self.startedAt = startedAt

        let shapes = SearchShape.allCases
        let colors = SearchColor.allCases
        self.target = VisualSearchTarget(
            shape: shapes.randomElement()!,
            color: colors.randomElement()!
        )
        self.currentLevel = config.startingLevel ?? config.initialSpec.level
        self.currentSpec = config.initialSpec
        self.currentBlockTrialCount = config.initialSpec.trialsPerBlock
        self.blockLevelHistory = [self.currentLevel]
        if config.isAdaptive {
            self.trials = Self.generateTrials(
                spec: config.initialSpec,
                sessionTarget: self.target,
                startId: 0,
                targetPresentRatio: config.targetPresentRatio
            )
        } else {
            var startId = 0
            for _ in 0..<config.blockCount {
                let blockTrials = Self.generateTrials(
                    spec: config.initialSpec,
                    sessionTarget: self.target,
                    startId: startId,
                    targetPresentRatio: config.targetPresentRatio
                )
                self.trials.append(contentsOf: blockTrials)
                startId += blockTrials.count
            }
        }
    }

    func beginTrial() {
        phase = .fixation
    }

    func showDisplay() {
        phase = .display
        displayOnsetTime = Date()
    }

    func recordResponse(userSaidPresent: Bool, at date: Date = Date()) -> VisualSearchTrialResult? {
        guard let trial = currentTrial, phase == .display else { return nil }
        let rt = displayOnsetTime.map { date.timeIntervalSince($0) }
        let result = VisualSearchTrialResult(trial: trial, userSaidPresent: userSaidPresent, reactionTime: rt)
        results.append(result)
        phase = .feedback(correct: result.correct)
        return result
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
            let blockTrials = Self.generateTrials(
                spec: currentSpec,
                sessionTarget: target,
                startId: trials.count,
                targetPresentRatio: config.targetPresentRatio
            )
            trials.append(contentsOf: blockTrials)
        }
        phase = .idle
    }

    func randomITI() -> Int {
        Int.random(in: config.itiRangeMs)
    }

    func computeMetrics() -> VisualSearchMetrics {
        let correctResults = results.filter(\.correct)
        let accuracy = results.isEmpty ? 0 : Double(correctResults.count) / Double(results.count)

        let presentCorrect = correctResults.filter(\.targetPresent)
        let absentCorrect = correctResults.filter { !$0.targetPresent }

        let presentRTs = presentCorrect.compactMap(\.reactionTime)
        let absentRTs = absentCorrect.compactMap(\.reactionTime)

        let avgPresentRT = presentRTs.isEmpty ? 0 : presentRTs.reduce(0, +) / Double(presentRTs.count)
        let avgAbsentRT = absentRTs.isEmpty ? 0 : absentRTs.reduce(0, +) / Double(absentRTs.count)

        var setSizeRTs: [Int: TimeInterval] = [:]
        var slopeData: [(setSize: Int, rt: TimeInterval)] = []
        let grouped = Dictionary(grouping: correctResults) { $0.setSize }
        for (size, trials) in grouped {
            let rts = trials.compactMap(\.reactionTime)
            if !rts.isEmpty {
                let avg = rts.reduce(0, +) / Double(rts.count)
                setSizeRTs[size] = avg
                slopeData.append((size, avg))
            }
        }

        let slope = MetricsCalculator.searchSlope(setSizeRTs: slopeData)
        let errorRate = results.isEmpty ? 0 : Double(results.count - correctResults.count) / Double(results.count)

        return VisualSearchMetrics(
            totalTrials: results.count,
            accuracy: accuracy,
            searchSlope: slope,
            presentRT: avgPresentRT,
            absentRT: avgAbsentRT,
            setSizeRTs: setSizeRTs,
            errorRate: errorRate
        )
    }

    private func evaluateCurrentBlock() -> (AdaptiveBlockOutcome, Int, Double) {
        let blockResults = results.filter { $0.trialIndex >= currentBlockStartIndex && $0.trialIndex < currentBlockStartIndex + currentBlockTrialCount }
        let correctResults = blockResults.filter(\.correct)
        let accuracy = blockResults.isEmpty ? 0 : Double(correctResults.count) / Double(blockResults.count)
        let grouped = Dictionary(grouping: correctResults) { $0.setSize }
        let slopeData = grouped.compactMap { size, trials -> (setSize: Int, rt: TimeInterval)? in
            let rts = trials.compactMap(\.reactionTime)
            guard !rts.isEmpty else { return nil }
            return (size, rts.reduce(0, +) / Double(rts.count))
        }
        let searchSlope = MetricsCalculator.searchSlope(setSizeRTs: slopeData) * 1_000
        let meanRT = (correctResults.compactMap(\.reactionTime).average ?? 0) * 1_000
        let slopeScore = clamp((70 - searchSlope) / 50)
        let rtScore = clamp((2_500 - meanRT) / 2_000)
        let errorRate = blockResults.isEmpty ? 0 : Double(blockResults.count - correctResults.count) / Double(blockResults.count)
        let performanceIndex = clamp(0.40 * accuracy + 0.35 * slopeScore + 0.25 * rtScore)

        var nextLevel = currentLevel
        let outcome: AdaptiveBlockOutcome
        if accuracy >= 0.88 && searchSlope <= targetSearchSlopeMs(for: currentLevel) && performanceIndex >= 0.78 {
            nextLevel = min(currentLevel + 1, 6)
            outcome = nextLevel > currentLevel ? .promote : .stay
        } else if accuracy < 0.70 || errorRate > 0.25 || performanceIndex < 0.55 {
            nextLevel = max(currentLevel - 1, 1)
            outcome = nextLevel < currentLevel ? .demote : .stay
        } else {
            outcome = .stay
        }

        return (outcome, nextLevel, performanceIndex)
    }

    private func targetSearchSlopeMs(for level: Int) -> Double {
        switch level {
        case 1: 55
        case 2: 48
        case 3: 40
        case 4: 34
        case 5: 28
        default: 22
        }
    }

    private static func generateTrials(
        spec: VisualSearchLevelSpec,
        sessionTarget: VisualSearchTarget,
        startId: Int,
        targetPresentRatio: Double
    ) -> [VisualSearchTrial] {
        var trials: [VisualSearchTrial] = []

        for index in 0..<spec.trialsPerBlock {
            let setSize = spec.setSizes[index % spec.setSizes.count]
            let present = Double.random(in: 0...1) < targetPresentRatio

            let items = generateItems(
                setSize: setSize,
                target: sessionTarget,
                targetPresent: present,
                startId: (startId + index) * 100
            )
            trials.append(VisualSearchTrial(
                id: startId + index,
                target: sessionTarget,
                items: items,
                targetPresent: present,
                setSize: setSize
            ))
        }

        trials.shuffle()
        return trials
    }

    private static func generateItems(setSize: Int, target: VisualSearchTarget, targetPresent: Bool, startId: Int) -> [SearchItem] {
        var items: [SearchItem] = []
        let positions = generateRandomPositions(count: setSize)

        let distractorFeatures = generateDistractorFeatures(target: target, count: setSize - (targetPresent ? 1 : 0))

        var posIdx = 0
        if targetPresent {
            items.append(SearchItem(id: startId, shape: target.shape, color: target.color, position: positions[posIdx]))
            posIdx += 1
        }

        for (i, feat) in distractorFeatures.enumerated() {
            items.append(SearchItem(id: startId + i + 1, shape: feat.shape, color: feat.color, position: positions[posIdx]))
            posIdx += 1
        }

        return items.shuffled()
    }

    private static func generateDistractorFeatures(target: VisualSearchTarget, count: Int) -> [(shape: SearchShape, color: SearchColor)] {
        var features: [(SearchShape, SearchColor)] = []
        let otherShapes = SearchShape.allCases.filter { $0 != target.shape }
        let otherColors = SearchColor.allCases.filter { $0 != target.color }

        for _ in 0..<count {
            let shareShape = Bool.random()
            if shareShape {
                features.append((target.shape, otherColors.randomElement()!))
            } else {
                features.append((otherShapes.randomElement()!, target.color))
            }
        }
        return features
    }

    private static func generateRandomPositions(count: Int) -> [CGPoint] {
        var positions: [CGPoint] = []
        let cols = max(4, Int(ceil(sqrt(Double(count) * 1.5))))
        let rows = cols
        var cells: [(Int, Int)] = []
        for r in 0..<rows {
            for c in 0..<cols {
                cells.append((r, c))
            }
        }
        cells.shuffle()

        let cellW = 1.0 / Double(cols)
        let cellH = 1.0 / Double(rows)
        for i in 0..<min(count, cells.count) {
            let (r, c) = cells[i]
            let jitterX = Double.random(in: -0.15...0.15) * cellW
            let jitterY = Double.random(in: -0.15...0.15) * cellH
            let x = (Double(c) + 0.5) * cellW + jitterX
            let y = (Double(r) + 0.5) * cellH + jitterY
            positions.append(CGPoint(x: min(max(x, 0.05), 0.95), y: min(max(y, 0.05), 0.95)))
        }
        return positions
    }
}

private func clamp(_ value: Double) -> Double {
    min(max(value, 0), 1)
}
