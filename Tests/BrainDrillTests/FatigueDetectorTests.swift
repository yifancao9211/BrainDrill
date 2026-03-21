import Foundation
import Testing
@testable import BrainDrill

struct FatigueDetectorTests {
    @Test func noFatigueOnStablePerformance() {
        let rts: [TimeInterval] = [0.3, 0.31, 0.29, 0.30, 0.32, 0.28, 0.31, 0.30]
        let result = FatigueDetector.evaluate(recentRTs: rts, recentAccuracies: [1, 1, 1, 1, 1, 1, 1, 1])
        #expect(!result.isFatigued)
    }

    @Test func detectsFatigueOnRisingRT() {
        let rts: [TimeInterval] = [0.30, 0.32, 0.35, 0.38, 0.42, 0.46, 0.50, 0.55, 0.60, 0.65]
        let result = FatigueDetector.evaluate(recentRTs: rts, recentAccuracies: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1])
        #expect(result.isFatigued)
        #expect(result.rtTrend > 0)
    }

    @Test func detectsFatigueOnDroppingAccuracy() {
        let rts: [TimeInterval] = [0.30, 0.30, 0.30, 0.30, 0.30, 0.30, 0.30, 0.30]
        let accs: [Double] = [1, 1, 1, 0.8, 0.6, 0.5, 0.4, 0.3]
        let result = FatigueDetector.evaluate(recentRTs: rts, recentAccuracies: accs)
        #expect(result.isFatigued)
        #expect(result.accuracyTrend < 0)
    }

    @Test func tooFewSamplesReturnsNoFatigue() {
        let result = FatigueDetector.evaluate(recentRTs: [0.3, 0.5], recentAccuracies: [1, 0.5])
        #expect(!result.isFatigued)
    }

    @Test func linearTrendPositiveForIncreasing() {
        let values: [Double] = [1, 2, 3, 4, 5]
        let slope = FatigueDetector.linearTrend(values)
        #expect(slope > 0.9)
    }

    @Test func linearTrendNegativeForDecreasing() {
        let values: [Double] = [5, 4, 3, 2, 1]
        let slope = FatigueDetector.linearTrend(values)
        #expect(slope < -0.9)
    }

    @Test func linearTrendZeroForConstant() {
        let values: [Double] = [3, 3, 3, 3, 3]
        let slope = FatigueDetector.linearTrend(values)
        #expect(abs(slope) < 0.01)
    }
}
