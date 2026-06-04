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
            let dPrime = 2.5 + Double(i % 3) * 0.05
            return SessionResult(module: .changeDetection, startedAt: now.addingTimeInterval(Double(-i) * 86400), endedAt: now, duration: 60,
                          metrics: .changeDetection(ChangeDetectionMetrics(totalTrials: 30, accuracy: 0.92, dPrime: dPrime, hitRate: 0.92, falseAlarmRate: 0.10, maxSetSize: 5, averageRT: 0.5)))
        }
        let anomalous = SessionResult(module: .changeDetection, startedAt: now, endedAt: now, duration: 60,
                                      metrics: .changeDetection(ChangeDetectionMetrics(totalTrials: 30, accuracy: 0.55, dPrime: 0.3, hitRate: 0.55, falseAlarmRate: 0.40, maxSetSize: 3, averageRT: 1.2)))

        let result = AnomalyDetector.check(latest: anomalous, history: normal)
        #expect(result.isAnomalous)
        #expect(!result.anomalies.isEmpty)
    }

    @Test func noAnomalyOnNormalSession() {
        let now = Date()
        let sessions = (0..<10).map { i in
            SessionResult(module: .changeDetection, startedAt: now.addingTimeInterval(Double(-i) * 86400), endedAt: now, duration: 60,
                          metrics: .changeDetection(ChangeDetectionMetrics(totalTrials: 30, accuracy: 0.92, dPrime: 2.5, hitRate: 0.92, falseAlarmRate: 0.10, maxSetSize: 5, averageRT: 0.5)))
        }
        let result = AnomalyDetector.check(latest: sessions[0], history: Array(sessions.dropFirst()))
        #expect(!result.isAnomalous)
    }

    @Test func insufficientHistoryReturnsNoAnomaly() {
        let now = Date()
        let session = SessionResult(module: .changeDetection, startedAt: now, endedAt: now, duration: 90,
                                    metrics: .changeDetection(ChangeDetectionMetrics(totalTrials: 60, accuracy: 0.95, dPrime: 2.8, hitRate: 0.95, falseAlarmRate: 0.08, maxSetSize: 6, averageRT: 0.45)))
        let result = AnomalyDetector.check(latest: session, history: [])
        #expect(!result.isAnomalous)
    }
}

struct TimeOfDayAnalyzerTests {
    @Test func groupsByTimeSlot() {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())
        let morning = SessionResult(module: .changeDetection, startedAt: base.addingTimeInterval(9 * 3600), endedAt: base.addingTimeInterval(9 * 3600 + 60), duration: 60,
                                    metrics: .changeDetection(ChangeDetectionMetrics(totalTrials: 30, accuracy: 0.95, dPrime: 2.8, hitRate: 0.95, falseAlarmRate: 0.08, maxSetSize: 6, averageRT: 0.4)))
        let evening = SessionResult(module: .changeDetection, startedAt: base.addingTimeInterval(20 * 3600), endedAt: base.addingTimeInterval(20 * 3600 + 60), duration: 60,
                                    metrics: .changeDetection(ChangeDetectionMetrics(totalTrials: 30, accuracy: 0.85, dPrime: 1.5, hitRate: 0.85, falseAlarmRate: 0.20, maxSetSize: 4, averageRT: 0.7)))

        let analysis = TimeOfDayAnalyzer.analyze(sessions: [morning, evening])
        #expect(!analysis.slots.isEmpty)
    }

    @Test func identifiesBestTimeSlot() {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())
        var sessions: [SessionResult] = []
        for day in 0..<5 {
            let dayBase = base.addingTimeInterval(Double(-day) * 86400)
            sessions.append(SessionResult(module: .changeDetection, startedAt: dayBase.addingTimeInterval(9 * 3600), endedAt: dayBase.addingTimeInterval(9 * 3600 + 60), duration: 60,
                                          metrics: .changeDetection(ChangeDetectionMetrics(totalTrials: 30, accuracy: 0.95, dPrime: 3.0, hitRate: 0.95, falseAlarmRate: 0.06, maxSetSize: 6, averageRT: 0.38))))
            sessions.append(SessionResult(module: .changeDetection, startedAt: dayBase.addingTimeInterval(21 * 3600), endedAt: dayBase.addingTimeInterval(21 * 3600 + 60), duration: 60,
                                          metrics: .changeDetection(ChangeDetectionMetrics(totalTrials: 30, accuracy: 0.80, dPrime: 1.2, hitRate: 0.80, falseAlarmRate: 0.25, maxSetSize: 4, averageRT: 0.8))))
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
