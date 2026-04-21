import Foundation

enum AdaptiveScoring {
    static func nBackTiming(level: Int, internalSkillScore: Double, slowDownAfterPoorBlock: Bool) -> (stimulusMs: Int, isiMs: Int) {
        let speedBonus: Int
        switch internalSkillScore {
        case ..<40:
            speedBonus = 0
        case 40..<70:
            speedBonus = 100
        default:
            speedBonus = 180
        }

        var stimulus = clampInt(1200 - level * 90 - speedBonus, lower: 650, upper: 1400)
        var isi = clampInt(1900 - level * 110 - speedBonus / 2, lower: 900, upper: 2400)

        if slowDownAfterPoorBlock {
            stimulus = clampInt(stimulus + 120, lower: 650, upper: 1400)
            isi = clampInt(isi + 180, lower: 900, upper: 2400)
        }

        return (stimulus, isi)
    }

    static func performanceIndex(for result: SessionResult) -> Double {
        switch result.metrics {
        case let .mainIdea(metrics):
            return metrics.isCorrect ? 1 : 0

        case let .evidenceMap(metrics):
            return clamp(metrics.accuracy)

        case let .delayedRecall(metrics):
            return clamp(metrics.accuracy)

        case let .schulte(metrics):
            let score = AdaptiveDifficulty.sessionScore(
                result: SchulteSessionResult(
                    id: result.id,
                    startedAt: result.startedAt,
                    endedAt: result.endedAt,
                    duration: result.duration,
                    difficulty: metrics.difficulty,
                    mistakeCount: metrics.mistakeCount,
                    perNumberDurations: metrics.perNumberDurations
                )
            )
            return clamp(score / 1.25)

        case let .digitSpan(metrics):
            let maxSpan = max(metrics.maxSpanForward, metrics.maxSpanBackward)
            return clamp(0.6 * metrics.accuracy + 0.4 * (Double(maxSpan) / 9.0))

        case let .corsiBlock(metrics):
            return clamp(0.6 * metrics.accuracy + 0.4 * (Double(metrics.maxSpan) / 9.0))

        case let .nBack(metrics):
            let dPrimeScore = clamp((metrics.dPrime + 0.5) / 3.5)
            return clamp(0.5 * dPrimeScore + 0.3 * metrics.hitRate + 0.2 * (1.0 - metrics.falseAlarmRate))

        case let .changeDetection(metrics):
            let dPrimeScore = clamp(metrics.dPrime / 4.0)
            let levelScore = clamp(Double(metrics.maxSetSize) / 8.0)
            let rtScore = inverseScore(metrics.averageRT * 1000, good: 500, bad: 1800)
            return clamp(0.45 * dPrimeScore + 0.35 * levelScore + 0.20 * rtScore)

        case let .flanker(metrics):
            let speedScore = inverseScore(metrics.incongruentRT * 1000, good: 420, bad: 1200)
            let conflictScore = inverseScore(metrics.conflictCost * 1000, good: 40, bad: 220)
            return clamp(0.45 * metrics.accuracy + 0.35 * speedScore + 0.20 * conflictScore)

        case let .goNoGo(metrics):
            let dPrimeScore = clamp(metrics.dPrime / 4.0)
            let speedScore = inverseScore(metrics.goRT * 1000, good: 320, bad: 850)
            return clamp(0.40 * dPrimeScore + 0.35 * metrics.noGoAccuracy + 0.25 * speedScore)

        case let .choiceRT(metrics):
            let medianRTScore = inverseScore(metrics.medianRT * 1000, good: 280, bad: 1100)
            let anticipationRate = metrics.totalTrials == 0 ? 0 : Double(metrics.anticipationCount) / Double(metrics.totalTrials)
            let variabilityPenalty = clamp((metrics.rtStandardDeviation * 1000) / 350.0)
            let stabilityScore = clamp(1.0 - (0.6 * variabilityPenalty + 0.4 * min(1, anticipationRate / 0.2)))
            return clamp(0.45 * metrics.accuracy + 0.35 * medianRTScore + 0.20 * stabilityScore)

        case let .visualSearch(metrics):
            let slopeScore = inverseScore(metrics.searchSlope * 1000, good: 20, bad: 70)
            let rtScore = inverseScore(metrics.presentRT * 1000, good: 500, bad: 2500)
            return clamp(0.40 * metrics.accuracy + 0.35 * slopeScore + 0.25 * rtScore)

        case let .stopSignal(metrics):
            let ssrtScore = inverseScore(metrics.ssrt * 1000, good: 160, bad: 420)
            return clamp(0.45 * ssrtScore + 0.35 * metrics.inhibitionRate + 0.20 * metrics.goAccuracy)

        case let .syllogism(metrics):
            let dPrimeScore = clamp((metrics.dPrime + 0.5) / 3.5)
            let rtScore = inverseScore(metrics.medianRT * 1000, good: 3000, bad: 12000)
            return clamp(0.45 * dPrimeScore + 0.35 * metrics.accuracy + 0.20 * rtScore)

        case let .logicArgument(metrics):
            return clamp(metrics.compositeScore)
        }
    }

    static func updatedState(for result: SessionResult, current: ModuleAdaptiveState) -> ModuleAdaptiveState {
        let module = result.module
        let performanceIndex = performanceIndex(for: result)
        let suggestedLevel = nextRecommendedLevel(for: result, fallback: current.recommendedStartLevel)
        let levelNormalized = module.normalizedLevel(suggestedLevel)
        let observedSkill = 100 * (0.65 * levelNormalized + 0.35 * performanceIndex)
        let newSkill = current.internalSkillScore * 0.8 + observedSkill * 0.2
        let newSessionsPlayed = current.sessionsPlayed + 1
        let newConfidence = min(1, Double(newSessionsPlayed) / 10.0)
        let trend = performanceIndex - current.lastSessionPerformanceIndex

        return ModuleAdaptiveState(
            currentLevel: suggestedLevel,
            internalSkillScore: min(max(newSkill, 0), 100),
            confidence: newConfidence,
            recentTrend: trend,
            sessionsPlayed: newSessionsPlayed,
            lastSessionPerformanceIndex: performanceIndex,
            recommendedStartLevel: suggestedLevel
        )
    }

    static func nextRecommendedLevel(for result: SessionResult, fallback: Int) -> Int {
        if let explicit = result.conditions.customParameters["recommendedStartLevel"].flatMap(Int.init) {
            return explicit
        }
        if let explicit = result.conditions.customParameters["finalLevel"].flatMap(Int.init) {
            return explicit
        }

        switch result.metrics {
        case let .mainIdea(metrics):
            return min(max(metrics.difficulty, 1), 3)
        case let .evidenceMap(metrics):
            return min(max(metrics.difficulty, 1), 3)
        case let .delayedRecall(metrics):
            return min(max(metrics.difficulty, 1), 3)
        case let .schulte(metrics):
            return metrics.difficulty.gridSize - 2
        case let .digitSpan(metrics):
            return min(max(max(metrics.maxSpanForward, metrics.maxSpanBackward), 1), 6)
        case let .corsiBlock(metrics):
            return min(max(metrics.maxSpan, 1), 6)
        case let .nBack(metrics):
            return min(max(metrics.nLevel, 1), 6)
        case let .changeDetection(metrics):
            return min(max(metrics.maxSetSize - 1, 1), 6)
        case let .syllogism(metrics):
            return min(max(metrics.difficulty, 1), 3)
        case let .logicArgument(metrics):
            return min(max(metrics.difficulty, 1), 3)
        default:
            return fallback
        }
    }

    private static func inverseScore(_ value: Double, good: Double, bad: Double) -> Double {
        guard bad > good else { return 0 }
        return clamp((bad - value) / (bad - good))
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private static func clampInt(_ value: Int, lower: Int, upper: Int) -> Int {
        min(max(value, lower), upper)
    }
}
