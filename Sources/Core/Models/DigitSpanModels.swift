import Foundation

enum DigitSpanMode: String, Codable, CaseIterable, Identifiable {
    case forward
    case backward

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .forward:  "正背"
        case .backward: "倒背"
        }
    }
}

struct DigitSpanTrial: Identifiable, Equatable {
    let id: Int
    let sequence: [Int]
    let mode: DigitSpanMode

    var length: Int { sequence.count }

    var expectedResponse: [Int] {
        mode == .forward ? sequence : sequence.reversed()
    }
}

struct DigitSpanTrialResult: Equatable {
    let trialIndex: Int
    let sequence: [Int]
    let userInput: [Int]
    let mode: DigitSpanMode
    let correct: Bool
    let positionErrors: Int
    let spanLength: Int

    init(trial: DigitSpanTrial, userInput: [Int]) {
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

struct DigitSpanSessionConfig: Equatable {
    var startingLength: Int
    var maxLength: Int
    var presentationMs: Int
    var mode: DigitSpanMode
    var consecutiveCorrectToAdvance: Int
    var consecutiveWrongToDemote: Int

    init(
        startingLength: Int = 3,
        maxLength: Int = 12,
        presentationMs: Int = 1000,
        mode: DigitSpanMode = .forward,
        consecutiveCorrectToAdvance: Int = 2,
        consecutiveWrongToDemote: Int = 2
    ) {
        self.startingLength = startingLength
        self.maxLength = maxLength
        self.presentationMs = presentationMs
        self.mode = mode
        self.consecutiveCorrectToAdvance = consecutiveCorrectToAdvance
        self.consecutiveWrongToDemote = consecutiveWrongToDemote
    }
}
