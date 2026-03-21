import Foundation
import Testing
@testable import BrainDrill

struct SpeedAccuracyAnalyzerTests {
    @Test func detectsSpeedBias() {
        let trials: [SATrialData] = (0..<20).map { _ in
            SATrialData(rt: 0.20, correct: Bool.random() ? true : false)
        }
        let biased = trials.map { SATrialData(rt: $0.rt, correct: false) }
        let result = SpeedAccuracyAnalyzer.evaluate(trials: biased)
        #expect(result.bias == .speed)
    }

    @Test func detectsAccuracyBias() {
        let trials = (0..<20).map { _ in SATrialData(rt: 0.80, correct: true) }
        let result = SpeedAccuracyAnalyzer.evaluate(trials: trials)
        #expect(result.bias == .accuracy)
    }

    @Test func detectsBalanced() {
        let trials = (0..<20).map { _ in SATrialData(rt: 0.35, correct: true) }
        let result = SpeedAccuracyAnalyzer.evaluate(trials: trials)
        #expect(result.bias == .balanced)
    }

    @Test func tooFewTrialsReturnsUnknown() {
        let trials = [SATrialData(rt: 0.3, correct: true)]
        let result = SpeedAccuracyAnalyzer.evaluate(trials: trials)
        #expect(result.bias == .unknown)
    }

    @Test func adviceForSpeedBias() {
        let trials = (0..<20).map { _ in SATrialData(rt: 0.18, correct: false) }
        let result = SpeedAccuracyAnalyzer.evaluate(trials: trials)
        #expect(result.advice != nil)
        #expect(result.advice!.contains("慢"))
    }
}

struct AttentionLapseDetectorTests {
    @Test func detectsLapses() {
        var rts: [TimeInterval] = Array(repeating: 0.35, count: 18)
        rts.append(1.2)
        rts.append(0.34)
        let result = AttentionLapseDetector.analyze(reactionTimes: rts)
        #expect(result.lapseCount >= 1)
        #expect(result.lapseIndices.contains(18))
    }

    @Test func noLapsesOnConsistentRTs() {
        let rts: [TimeInterval] = Array(repeating: 0.35, count: 20)
        let result = AttentionLapseDetector.analyze(reactionTimes: rts)
        #expect(result.lapseCount == 0)
    }

    @Test func lapseRateComputed() {
        var rts: [TimeInterval] = Array(repeating: 0.30, count: 8)
        rts.append(1.0)
        rts.append(1.2)
        let result = AttentionLapseDetector.analyze(reactionTimes: rts)
        #expect(result.lapseRate > 0)
        #expect(result.lapseRate <= 1)
    }

    @Test func emptyInputReturnsZero() {
        let result = AttentionLapseDetector.analyze(reactionTimes: [])
        #expect(result.lapseCount == 0)
        #expect(result.lapseRate == 0)
    }
}

struct WarmupDetectorTests {
    @Test func detectsWarmupTrials() {
        var rts: [TimeInterval] = [0.8, 0.6, 0.45, 0.35, 0.33, 0.32, 0.31, 0.30, 0.30, 0.31]
        let count = WarmupDetector.detectWarmupCount(reactionTimes: rts)
        #expect(count >= 2)
        #expect(count <= 5)
    }

    @Test func noWarmupOnFlatRTs() {
        let rts: [TimeInterval] = Array(repeating: 0.35, count: 10)
        let count = WarmupDetector.detectWarmupCount(reactionTimes: rts)
        #expect(count == 0)
    }

    @Test func excludeWarmupFromRTs() {
        let rts: [TimeInterval] = [0.8, 0.6, 0.35, 0.33, 0.32, 0.31]
        let warmup = WarmupDetector.detectWarmupCount(reactionTimes: rts)
        let cleaned = Array(rts.dropFirst(warmup))
        let originalMedian = MetricsCalculator.medianRT(rts)
        let cleanedMedian = MetricsCalculator.medianRT(cleaned)
        #expect(cleanedMedian <= originalMedian)
    }

    @Test func tooFewTrialsReturnsZero() {
        let rts: [TimeInterval] = [0.5, 0.3]
        #expect(WarmupDetector.detectWarmupCount(reactionTimes: rts) == 0)
    }
}

struct AnomalyDetectorTests {
    @Test func detectsDropInPerformance() {
        let now = Date()
        let normal = (0..<10).map { i in
            SessionResult(module: .choiceRT, startedAt: now.addingTimeInterval(Double(-i) * 86400), endedAt: now, duration: 60,
                          metrics: .choiceRT(ChoiceRTMetrics(totalTrials: 30, medianRT: 0.35, rtStandardDeviation: 0.04, accuracy: 0.92, postErrorSlowing: 0.02, anticipationCount: 0, choiceCount: 2)))
        }
        let anomalous = SessionResult(module: .choiceRT, startedAt: now, endedAt: now, duration: 60,
                                      metrics: .choiceRT(ChoiceRTMetrics(totalTrials: 30, medianRT: 0.60, rtStandardDeviation: 0.12, accuracy: 0.55, postErrorSlowing: 0.08, anticipationCount: 3, choiceCount: 2)))

        let result = AnomalyDetector.check(latest: anomalous, history: normal)
        #expect(result.isAnomalous)
        #expect(!result.anomalies.isEmpty)
    }

    @Test func noAnomalyOnNormalSession() {
        let now = Date()
        let sessions = (0..<10).map { i in
            SessionResult(module: .choiceRT, startedAt: now.addingTimeInterval(Double(-i) * 86400), endedAt: now, duration: 60,
                          metrics: .choiceRT(ChoiceRTMetrics(totalTrials: 30, medianRT: 0.35, rtStandardDeviation: 0.04, accuracy: 0.92, postErrorSlowing: 0.02, anticipationCount: 0, choiceCount: 2)))
        }
        let result = AnomalyDetector.check(latest: sessions[0], history: Array(sessions.dropFirst()))
        #expect(!result.isAnomalous)
    }

    @Test func insufficientHistoryReturnsNoAnomaly() {
        let now = Date()
        let session = SessionResult(module: .goNoGo, startedAt: now, endedAt: now, duration: 90,
                                    metrics: .goNoGo(GoNoGoMetrics(totalTrials: 60, goRT: 0.35, goAccuracy: 0.95, noGoAccuracy: 0.85, dPrime: 2.5)))
        let result = AnomalyDetector.check(latest: session, history: [])
        #expect(!result.isAnomalous)
    }
}

struct TimeOfDayAnalyzerTests {
    @Test func groupsByTimeSlot() {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())
        let morning = SessionResult(module: .choiceRT, startedAt: base.addingTimeInterval(9 * 3600), endedAt: base.addingTimeInterval(9 * 3600 + 60), duration: 60,
                                    metrics: .choiceRT(ChoiceRTMetrics(totalTrials: 30, medianRT: 0.30, rtStandardDeviation: 0.03, accuracy: 0.95, postErrorSlowing: 0.01, anticipationCount: 0, choiceCount: 2)))
        let evening = SessionResult(module: .choiceRT, startedAt: base.addingTimeInterval(20 * 3600), endedAt: base.addingTimeInterval(20 * 3600 + 60), duration: 60,
                                    metrics: .choiceRT(ChoiceRTMetrics(totalTrials: 30, medianRT: 0.45, rtStandardDeviation: 0.06, accuracy: 0.85, postErrorSlowing: 0.03, anticipationCount: 1, choiceCount: 2)))

        let analysis = TimeOfDayAnalyzer.analyze(sessions: [morning, evening])
        #expect(!analysis.slots.isEmpty)
    }

    @Test func identifiesBestTimeSlot() {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())
        var sessions: [SessionResult] = []
        for day in 0..<5 {
            let dayBase = base.addingTimeInterval(Double(-day) * 86400)
            sessions.append(SessionResult(module: .choiceRT, startedAt: dayBase.addingTimeInterval(9 * 3600), endedAt: dayBase.addingTimeInterval(9 * 3600 + 60), duration: 60,
                                          metrics: .choiceRT(ChoiceRTMetrics(totalTrials: 30, medianRT: 0.28, rtStandardDeviation: 0.03, accuracy: 0.95, postErrorSlowing: 0.01, anticipationCount: 0, choiceCount: 2))))
            sessions.append(SessionResult(module: .choiceRT, startedAt: dayBase.addingTimeInterval(21 * 3600), endedAt: dayBase.addingTimeInterval(21 * 3600 + 60), duration: 60,
                                          metrics: .choiceRT(ChoiceRTMetrics(totalTrials: 30, medianRT: 0.50, rtStandardDeviation: 0.08, accuracy: 0.80, postErrorSlowing: 0.05, anticipationCount: 2, choiceCount: 2))))
        }

        let analysis = TimeOfDayAnalyzer.analyze(sessions: sessions)
        #expect(analysis.bestSlot != nil)
        #expect(analysis.bestSlot?.name == "上午")
    }

    @Test func emptySessionsReturnsEmpty() {
        let analysis = TimeOfDayAnalyzer.analyze(sessions: [])
        #expect(analysis.slots.isEmpty)
        #expect(analysis.bestSlot == nil)
    }
}
