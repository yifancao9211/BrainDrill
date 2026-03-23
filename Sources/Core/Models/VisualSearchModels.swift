import Foundation

enum SearchShape: Int, CaseIterable, Codable, Equatable {
    case circle = 0
    case square = 1
    case triangle = 2
}

enum SearchColor: Int, CaseIterable, Codable, Equatable {
    case red = 0
    case blue = 1
    case green = 2
}

struct SearchItem: Identifiable, Equatable {
    let id: Int
    let shape: SearchShape
    let color: SearchColor
    let position: CGPoint
}

struct VisualSearchTarget: Equatable {
    let shape: SearchShape
    let color: SearchColor
}

struct VisualSearchTrial: Identifiable, Equatable {
    let id: Int
    let target: VisualSearchTarget
    let items: [SearchItem]
    let targetPresent: Bool
    let setSize: Int

    var targetItem: SearchItem? {
        items.first { $0.shape == target.shape && $0.color == target.color }
    }
}

struct VisualSearchTrialResult: Equatable {
    let trialIndex: Int
    let setSize: Int
    let targetPresent: Bool
    let userSaidPresent: Bool
    let correct: Bool
    let reactionTime: TimeInterval?

    init(trial: VisualSearchTrial, userSaidPresent: Bool, reactionTime: TimeInterval?) {
        self.trialIndex = trial.id
        self.setSize = trial.setSize
        self.targetPresent = trial.targetPresent
        self.userSaidPresent = userSaidPresent
        self.reactionTime = reactionTime
        self.correct = (targetPresent == userSaidPresent)
    }
}

struct VisualSearchLevelSpec: Equatable {
    let level: Int
    let setSizes: [Int]
    let trialsPerBlock: Int
    let fixationMs: Int
    let feedbackMs: Int
}

struct VisualSearchSessionConfig: Equatable {
    var blockCount: Int
    var startingLevel: Int?
    var manualSetSizes: [Int]?
    var manualTrialsPerSize: Int?
    var targetPresentRatio: Double
    var manualFixationMs: Int?
    var manualFeedbackMs: Int?
    var itiRangeMs: ClosedRange<Int>

    init(
        setSizes: [Int]? = [8, 16, 24],
        trialsPerSize: Int? = 6,
        targetPresentRatio: Double = 0.5,
        fixationMs: Int? = 500,
        feedbackMs: Int? = 300,
        itiRangeMs: ClosedRange<Int> = 400...800,
        blockCount: Int = 1,
        startingLevel: Int? = nil
    ) {
        self.blockCount = blockCount
        self.startingLevel = startingLevel
        self.manualSetSizes = setSizes
        self.manualTrialsPerSize = trialsPerSize
        self.targetPresentRatio = targetPresentRatio
        self.manualFixationMs = fixationMs
        self.manualFeedbackMs = feedbackMs
        self.itiRangeMs = itiRangeMs
    }

    var isAdaptive: Bool { startingLevel != nil }

    var initialSpec: VisualSearchLevelSpec {
        if let startingLevel {
            return spec(for: startingLevel)
        }
        let setSizes = manualSetSizes ?? [8, 16, 24]
        let trialsPerSize = manualTrialsPerSize ?? 6
        return VisualSearchLevelSpec(
            level: 3,
            setSizes: setSizes,
            trialsPerBlock: setSizes.count * trialsPerSize,
            fixationMs: manualFixationMs ?? 500,
            feedbackMs: manualFeedbackMs ?? 300
        )
    }

    func spec(for level: Int) -> VisualSearchLevelSpec {
        switch min(max(level, 1), 6) {
        case 1:
            return VisualSearchLevelSpec(level: 1, setSizes: [6, 10], trialsPerBlock: 8, fixationMs: 420, feedbackMs: 320)
        case 2:
            return VisualSearchLevelSpec(level: 2, setSizes: [8, 12], trialsPerBlock: 8, fixationMs: 380, feedbackMs: 300)
        case 3:
            return VisualSearchLevelSpec(level: 3, setSizes: [8, 16], trialsPerBlock: 8, fixationMs: 360, feedbackMs: 260)
        case 4:
            return VisualSearchLevelSpec(level: 4, setSizes: [12, 20], trialsPerBlock: 8, fixationMs: 340, feedbackMs: 240)
        case 5:
            return VisualSearchLevelSpec(level: 5, setSizes: [16, 24], trialsPerBlock: 8, fixationMs: 320, feedbackMs: 220)
        default:
            return VisualSearchLevelSpec(level: 6, setSizes: [20, 32], trialsPerBlock: 8, fixationMs: 300, feedbackMs: 200)
        }
    }
}
