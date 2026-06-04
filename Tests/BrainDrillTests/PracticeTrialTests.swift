import Foundation
import Testing
@testable import BrainDrill

struct PracticeTrialTests {
    @Test func practiceManagerGeneratesTrials() {
        let manager = PracticeTrialManager(module: .nBack, count: 3)
        #expect(manager.totalTrials == 3)
        #expect(manager.completedTrials == 0)
        #expect(!manager.isComplete)
    }

    @Test func advancesAndCompletes() {
        let manager = PracticeTrialManager(module: .changeDetection, count: 2)
        manager.recordTrial()
        #expect(manager.completedTrials == 1)
        #expect(!manager.isComplete)
        manager.recordTrial()
        #expect(manager.completedTrials == 2)
        #expect(manager.isComplete)
    }

    @Test func practiceResultsNotRecorded() {
        let manager = PracticeTrialManager(module: .nBack, count: 3)
        #expect(manager.isPractice)
        for _ in 0..<3 {
            manager.recordTrial()
        }
        #expect(manager.isComplete)
    }

    @Test func zeroCountImmediatelyComplete() {
        let manager = PracticeTrialManager(module: .nBack, count: 0)
        #expect(manager.isComplete)
    }

    @Test func defaultCountPerModule() {
        #expect(PracticeTrialManager.defaultCount(for: .digitSpan) == 2)
        #expect(PracticeTrialManager.defaultCount(for: .changeDetection) == 2)
        #expect(PracticeTrialManager.defaultCount(for: .schulte) == 0)
    }
}
