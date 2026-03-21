import Foundation
import Testing
@testable import BrainDrill

struct ChoiceRTEngineTests {
    @Test func generatesCorrectTrialCount() {
        let config = ChoiceRTSessionConfig(choiceCount: 2, trialsPerBlock: 20, blockCount: 1)
        let engine = ChoiceRTEngine(config: config)
        #expect(engine.trials.count == 20)
    }

    @Test func trialsContainAllChoices() {
        let config = ChoiceRTSessionConfig(choiceCount: 3, trialsPerBlock: 30, blockCount: 1)
        let engine = ChoiceRTEngine(config: config)
        let indices = Set(engine.trials.map(\.correctResponseIndex))
        #expect(indices.count == 3)
    }

    @Test func correctResponseRecorded() {
        let config = ChoiceRTSessionConfig(choiceCount: 2, trialsPerBlock: 5, blockCount: 1)
        let engine = ChoiceRTEngine(config: config)

        engine.beginTrial()
        engine.showStimulus()
        let trial = engine.currentTrial!
        let responseTime = engine.stimulusOnsetTime!.addingTimeInterval(0.35)
        let result = engine.recordResponse(trial.correctResponseIndex, at: responseTime)
        #expect(result?.correct == true)
        #expect(result?.reactionTime != nil)
        #expect(result?.isAnticipation == false)
    }

    @Test func incorrectResponseRecorded() {
        let config = ChoiceRTSessionConfig(choiceCount: 2, trialsPerBlock: 5, blockCount: 1)
        let engine = ChoiceRTEngine(config: config)

        engine.beginTrial()
        engine.showStimulus()
        let trial = engine.currentTrial!
        let wrong = (trial.correctResponseIndex + 1) % config.choiceCount
        let result = engine.recordResponse(wrong)
        #expect(result?.correct == false)
    }

    @Test func anticipationDetected() {
        let config = ChoiceRTSessionConfig(choiceCount: 2, trialsPerBlock: 5, blockCount: 1)
        let engine = ChoiceRTEngine(config: config)

        engine.beginTrial()
        engine.showStimulus()
        let trial = engine.currentTrial!
        let now = engine.stimulusOnsetTime!
        let result = engine.recordResponse(trial.correctResponseIndex, at: now.addingTimeInterval(0.05))
        #expect(result?.isAnticipation == true)
        #expect(result?.correct == false)
    }

    @Test func timeoutRecorded() {
        let config = ChoiceRTSessionConfig(choiceCount: 2, trialsPerBlock: 5, blockCount: 1)
        let engine = ChoiceRTEngine(config: config)

        engine.beginTrial()
        engine.showStimulus()
        engine.recordTimeout()
        #expect(engine.results.count == 1)
        #expect(engine.results.first?.correct == false)
        #expect(engine.results.first?.reactionTime == nil)
    }

    @Test func metricsComputed() {
        let config = ChoiceRTSessionConfig(choiceCount: 2, trialsPerBlock: 10, blockCount: 1)
        let engine = ChoiceRTEngine(config: config)

        for trial in engine.trials {
            engine.showStimulus()
            _ = engine.recordResponse(trial.correctResponseIndex, at: Date().addingTimeInterval(0.35))
            engine.advanceToNext()
        }

        let m = engine.computeMetrics()
        #expect(m.totalTrials == 10)
        #expect(m.accuracy > 0.99)
        #expect(m.medianRT > 0)
        #expect(m.anticipationCount == 0)
    }

    @Test func completesAfterAllTrials() {
        let config = ChoiceRTSessionConfig(choiceCount: 2, trialsPerBlock: 3, blockCount: 1)
        let engine = ChoiceRTEngine(config: config)

        for trial in engine.trials {
            engine.showStimulus()
            _ = engine.recordResponse(trial.correctResponseIndex)
            engine.advanceToNext()
        }

        #expect(engine.isComplete)
        #expect(engine.phase == .completed)
    }
}
