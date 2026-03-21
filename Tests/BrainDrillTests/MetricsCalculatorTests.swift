import Foundation
import Testing
@testable import BrainDrill

struct MetricsCalculatorTests {
    @Test func medianOddCount() {
        let result = MetricsCalculator.median([3, 1, 2])
        #expect(result == 2.0)
    }

    @Test func medianEvenCount() {
        let result = MetricsCalculator.median([4, 1, 3, 2])
        #expect(result == 2.5)
    }

    @Test func medianEmpty() {
        #expect(MetricsCalculator.median([]) == 0)
    }

    @Test func standardDeviationComputed() {
        let sd = MetricsCalculator.standardDeviation([2, 4, 4, 4, 5, 5, 7, 9])
        #expect(sd > 2.13 && sd < 2.15)
    }

    @Test func standardDeviationSingleValue() {
        #expect(MetricsCalculator.standardDeviation([5]) == 0)
    }

    @Test func coefficientOfVariation() {
        let cv = MetricsCalculator.coefficientOfVariation([10, 10, 10])
        #expect(cv == 0)

        let cv2 = MetricsCalculator.coefficientOfVariation([1, 2, 3])
        #expect(cv2 > 0)
    }

    @Test func dPrimePerfectPerformance() {
        let dp = MetricsCalculator.dPrime(hitRate: 0.99, falseAlarmRate: 0.01)
        #expect(dp > 3.0)
    }

    @Test func dPrimeChancePerformance() {
        let dp = MetricsCalculator.dPrime(hitRate: 0.5, falseAlarmRate: 0.5)
        #expect(abs(dp) < 0.1)
    }

    @Test func dPrimeClampsExtremes() {
        let dp = MetricsCalculator.dPrime(hitRate: 1.0, falseAlarmRate: 0.0)
        #expect(dp.isFinite)
        #expect(dp > 0)
    }

    @Test func anticipationFilter() {
        let rts: [TimeInterval] = [0.05, 0.15, 0.30, 0.12, 0.45]
        let filtered = MetricsCalculator.filterAnticipations(rts)
        #expect(filtered == [0.15, 0.30, 0.45])
    }

    @Test func postErrorSlowingPositive() {
        let results: [(correct: Bool, rt: TimeInterval?)] = [
            (true, 0.3),
            (false, 0.35),
            (true, 0.50),
            (true, 0.30),
        ]
        let pes = MetricsCalculator.postErrorSlowing(results: results)
        #expect(pes > 0)
    }

    @Test func postErrorSlowingNoErrors() {
        let results: [(correct: Bool, rt: TimeInterval?)] = [
            (true, 0.3),
            (true, 0.35),
            (true, 0.30),
        ]
        let pes = MetricsCalculator.postErrorSlowing(results: results)
        #expect(pes == 0)
    }

    @Test func searchSlopeLinear() {
        let data: [(setSize: Int, rt: TimeInterval)] = [
            (8, 0.5),
            (16, 0.7),
            (24, 0.9),
        ]
        let slope = MetricsCalculator.searchSlope(setSizeRTs: data)
        #expect(abs(slope - 0.025) < 0.001)
    }

    @Test func searchSlopeSinglePoint() {
        let data: [(setSize: Int, rt: TimeInterval)] = [(8, 0.5)]
        #expect(MetricsCalculator.searchSlope(setSizeRTs: data) == 0)
    }

    @Test func zScoreSymmetric() {
        let z50 = MetricsCalculator.zScore(0.5)
        #expect(abs(z50) < 0.01)

        let z84 = MetricsCalculator.zScore(0.84)
        let z16 = MetricsCalculator.zScore(0.16)
        #expect(abs(z84 + z16) < 0.1)
    }
}
