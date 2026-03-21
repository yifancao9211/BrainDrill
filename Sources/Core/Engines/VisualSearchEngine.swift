import Foundation
import Observation

@Observable
final class VisualSearchEngine {
    let config: VisualSearchSessionConfig
    let trials: [VisualSearchTrial]
    let target: VisualSearchTarget
    let startedAt: Date

    private(set) var currentTrialIndex: Int = 0
    private(set) var results: [VisualSearchTrialResult] = []
    private(set) var phase: Phase = .idle
    private(set) var displayOnsetTime: Date?

    enum Phase: Equatable, Hashable {
        case idle
        case fixation
        case display
        case feedback(correct: Bool)
        case iti
        case completed
    }

    var currentTrial: VisualSearchTrial? {
        guard currentTrialIndex < trials.count else { return nil }
        return trials[currentTrialIndex]
    }

    var completionFraction: Double {
        Double(currentTrialIndex) / Double(trials.count)
    }

    var isComplete: Bool { phase == .completed }

    init(config: VisualSearchSessionConfig, startedAt: Date = Date()) {
        self.config = config
        self.startedAt = startedAt

        let shapes = SearchShape.allCases
        let colors = SearchColor.allCases
        self.target = VisualSearchTarget(
            shape: shapes.randomElement()!,
            color: colors.randomElement()!
        )

        self.trials = Self.generateTrials(config: config, target: self.target)
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
        if currentTrialIndex >= trials.count {
            phase = .completed
        } else {
            phase = .iti
        }
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

    private static func generateTrials(config: VisualSearchSessionConfig, target: VisualSearchTarget) -> [VisualSearchTrial] {
        var trials: [VisualSearchTrial] = []
        var id = 0

        for setSize in config.setSizes {
            for _ in 0..<config.trialsPerSize {
                let present = Double.random(in: 0...1) < config.targetPresentRatio
                let items = generateItems(setSize: setSize, target: target, targetPresent: present, startId: id * 100)
                trials.append(VisualSearchTrial(
                    id: id,
                    target: target,
                    items: items,
                    targetPresent: present,
                    setSize: setSize
                ))
                id += 1
            }
        }

        trials.shuffle()
        for i in 0..<trials.count {
            let t = trials[i]
            trials[i] = VisualSearchTrial(id: i, target: t.target, items: t.items, targetPresent: t.targetPresent, setSize: t.setSize)
        }

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
