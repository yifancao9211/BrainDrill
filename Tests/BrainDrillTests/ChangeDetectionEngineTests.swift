import Foundation
import Testing
@testable import BrainDrill

struct ChangeDetectionEngineTests {
    @Test func startsAtConfiguredSetSize() {
        let config = ChangeDetectionSessionConfig(initialSetSize: 4, trialsPerBlock: 10, blockCount: 1)
        let engine = ChangeDetectionEngine(config: config)
        #expect(engine.currentSetSize == 4)
    }

    @Test func trialGeneratesCorrectColors() {
        let config = ChangeDetectionSessionConfig(initialSetSize: 3, trialsPerBlock: 5, blockCount: 1)
        let engine = ChangeDetectionEngine(config: config)

        engine.beginTrial()
        let trial = engine.currentTrial!
        #expect(trial.originalColors.count == 3)
        #expect(trial.positions.count == 3)
        #expect(Set(trial.originalColors).count == 3)
    }

    @Test func changeTrialModifiesOneColor() {
        let config = ChangeDetectionSessionConfig(initialSetSize: 4, trialsPerBlock: 20, blockCount: 1, changeRatio: 1.0)
        let engine = ChangeDetectionEngine(config: config)

        engine.beginTrial()
        let trial = engine.currentTrial!
        #expect(trial.isChangePresent)
        #expect(trial.changedIndex != nil)

        let probe = trial.probeColors
        var diffs = 0
        for i in 0..<trial.originalColors.count {
            if trial.originalColors[i] != probe[i] { diffs += 1 }
        }
        #expect(diffs == 1)
    }

    @Test func noChangeTrialKeepsColors() {
        let config = ChangeDetectionSessionConfig(initialSetSize: 3, trialsPerBlock: 20, blockCount: 1, changeRatio: 0.0)
        let engine = ChangeDetectionEngine(config: config)

        engine.beginTrial()
        let trial = engine.currentTrial!
        #expect(!trial.isChangePresent)
        #expect(trial.probeColors == trial.originalColors)
    }

    @Test func correctResponseRecorded() {
        let config = ChangeDetectionSessionConfig(initialSetSize: 3, trialsPerBlock: 5, blockCount: 1)
        let engine = ChangeDetectionEngine(config: config)

        engine.beginTrial()
        engine.startRetention()
        engine.showProbe()

        let trial = engine.currentTrial!
        let result = engine.recordResponse(userSaidChanged: trial.isChangePresent)
        #expect(result?.correct == true)
    }

    @Test func phaseProgression() {
        let config = ChangeDetectionSessionConfig(initialSetSize: 3, trialsPerBlock: 1, blockCount: 1)
        let engine = ChangeDetectionEngine(config: config)

        #expect(engine.phase == .idle)
        engine.beginTrial()
        #expect(engine.phase == .encoding)
        engine.startRetention()
        #expect(engine.phase == .retention)
        engine.showProbe()
        #expect(engine.phase == .probe)

        let trial = engine.currentTrial!
        _ = engine.recordResponse(userSaidChanged: trial.isChangePresent)
        if case .feedback = engine.phase {} else {
            Issue.record("Expected feedback phase")
        }

        engine.advanceToNext()
        #expect(engine.isComplete)
    }

    @Test func dPrimeComputed() {
        let config = ChangeDetectionSessionConfig(initialSetSize: 3, trialsPerBlock: 20, blockCount: 1)
        let engine = ChangeDetectionEngine(config: config)

        for _ in 0..<20 {
            engine.beginTrial()
            engine.startRetention()
            engine.showProbe()
            let trial = engine.currentTrial!
            _ = engine.recordResponse(userSaidChanged: trial.isChangePresent)
            engine.advanceToNext()
        }

        let m = engine.computeMetrics()
        #expect(m.totalTrials == 20)
        #expect(m.accuracy > 0.99)
        #expect(m.dPrime > 0)
    }
}
