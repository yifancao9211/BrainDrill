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

struct VisualSearchSessionConfig: Equatable {
    var setSizes: [Int]
    var trialsPerSize: Int
    var targetPresentRatio: Double
    var fixationMs: Int
    var feedbackMs: Int
    var itiRangeMs: ClosedRange<Int>

    init(
        setSizes: [Int] = [8, 16, 24],
        trialsPerSize: Int = 10,
        targetPresentRatio: Double = 0.5,
        fixationMs: Int = 500,
        feedbackMs: Int = 300,
        itiRangeMs: ClosedRange<Int> = 400...800
    ) {
        self.setSizes = setSizes
        self.trialsPerSize = trialsPerSize
        self.targetPresentRatio = targetPresentRatio
        self.fixationMs = fixationMs
        self.feedbackMs = feedbackMs
        self.itiRangeMs = itiRangeMs
    }
}
