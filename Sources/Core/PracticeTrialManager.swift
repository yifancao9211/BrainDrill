import Foundation
import Observation

@Observable
final class PracticeTrialManager {
    let module: TrainingModule
    let totalTrials: Int
    private(set) var completedTrials: Int = 0

    let isPractice = true

    var isComplete: Bool { completedTrials >= totalTrials }

    init(module: TrainingModule, count: Int) {
        self.module = module
        self.totalTrials = count
    }

    func recordTrial() {
        guard !isComplete else { return }
        completedTrials += 1
    }

    static func defaultCount(for module: TrainingModule) -> Int {
        switch module {
        case .choiceRT, .goNoGo, .flanker, .visualSearch, .stopSignal:
            return 3
        case .digitSpan, .changeDetection, .nBack, .corsiBlock:
            return 2
        case .schulte:
            return 0
        }
    }
}
