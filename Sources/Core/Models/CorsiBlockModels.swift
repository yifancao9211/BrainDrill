import Foundation

enum CorsiBlockMode: String, Codable, CaseIterable, Identifiable {
    case forward
    case backward

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .forward:  "正序"
        case .backward: "倒序"
        }
    }
}

struct CorsiBlockTrial: Identifiable, Equatable {
    let id: Int
    let sequence: [Int]
    let mode: CorsiBlockMode

    var length: Int { sequence.count }

    var expectedResponse: [Int] {
        mode == .forward ? sequence : sequence.reversed()
    }
}

struct CorsiBlockTrialResult: Equatable {
    let trialIndex: Int
    let sequence: [Int]
    let userInput: [Int]
    let mode: CorsiBlockMode
    let correct: Bool
    let positionErrors: Int
    let spanLength: Int

    init(trial: CorsiBlockTrial, userInput: [Int]) {
        self.trialIndex = trial.id
        self.sequence = trial.sequence
        self.userInput = userInput
        self.mode = trial.mode
        self.spanLength = trial.length

        let expected = trial.expectedResponse
        self.correct = userInput == expected

        var errors = 0
        for i in 0..<min(userInput.count, expected.count) {
            if userInput[i] != expected[i] { errors += 1 }
        }
        errors += abs(userInput.count - expected.count)
        self.positionErrors = errors
    }
}

struct CorsiBlockSessionConfig: Equatable {
    var startingLength: Int
    var minLength: Int
    var maxLength: Int
    var gridSize: Int
    var presentationMs: Int
    var mode: CorsiBlockMode
    /// 自适应阶梯法：答对升一档、答错降一档，累计到此反转次数即结束本局。
    var reversalsToComplete: Int
    /// 安全上限：即使反转未满，达到此试次数也强制结束，避免极端情况下无限延长。
    var maxTrials: Int

    init(
        startingLength: Int = 3,
        minLength: Int = 2,
        // 上限必须小于格子总数：长度=格子数时最后一格是必然剩下的那个，等于白送。
        maxLength: Int = 8,
        gridSize: Int = 9,
        presentationMs: Int = 800,
        mode: CorsiBlockMode = .forward,
        reversalsToComplete: Int = 6,
        maxTrials: Int = 30
    ) {
        self.startingLength = startingLength
        self.minLength = minLength
        self.maxLength = maxLength
        self.gridSize = gridSize
        self.presentationMs = presentationMs
        self.mode = mode
        self.reversalsToComplete = reversalsToComplete
        self.maxTrials = maxTrials
    }
}
