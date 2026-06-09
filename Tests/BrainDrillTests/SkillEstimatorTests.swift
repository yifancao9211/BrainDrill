import Testing
import Foundation
@testable import BrainDrill

struct SkillEstimatorTests {
    private func qb(_ module: TrainingModule, difficulty: Int, accuracy: Double, daysAgo: Int = 0) -> SessionResult {
        let end = Date(timeIntervalSince1970: 1_000_000 - Double(daysAgo) * 86_400)
        let m = BankPracticeMetrics(
            section: .logicReasoning, difficulty: difficulty,
            totalQuestions: 10, correctCount: Int(accuracy * 10), accuracy: accuracy
        )
        return SessionResult(module: module, startedAt: end, endedAt: end, duration: 60, metrics: .questionBank(m))
    }

    @Test
    func sessionThetaIsMonotonic() {
        let lowLow = SkillEstimator.sessionTheta(module: .logicReasoning, level: 1, performance: 0.4)
        let highHigh = SkillEstimator.sessionTheta(module: .logicReasoning, level: 3, performance: 1.0)
        #expect(highHigh >= 99)
        #expect(lowLow <= 1)
        // 同档位：正确率高 → θ 高
        #expect(SkillEstimator.sessionTheta(module: .logicReasoning, level: 2, performance: 0.9)
              > SkillEstimator.sessionTheta(module: .logicReasoning, level: 2, performance: 0.5))
        // 同正确率：档位高 → θ 高
        #expect(SkillEstimator.sessionTheta(module: .logicReasoning, level: 3, performance: 0.72)
              > SkillEstimator.sessionTheta(module: .logicReasoning, level: 1, performance: 0.72))
    }

    @Test
    func untrainedModuleHasNoData() {
        let e = SkillEstimator.estimate(module: .nBack, sessions: [])
        #expect(!e.hasData)
        #expect(e.reliability == 0)
        #expect(e.sessions == 0)
    }

    @Test
    func reliabilityGrowsWithSessions() {
        let few = SkillEstimator.estimate(module: .logicReasoning, sessions: [qb(.logicReasoning, difficulty: 2, accuracy: 0.8)])
        let many = SkillEstimator.estimate(module: .logicReasoning, sessions: (0..<12).map { qb(.logicReasoning, difficulty: 2, accuracy: 0.8, daysAgo: $0) })
        #expect(abs(few.reliability - 1.0 / 5.0) < 1e-9)   // n=1, k=4
        #expect(many.reliability > few.reliability)
    }

    @Test
    func untrainedCategoriesDoNotDragOverall() {
        // 只练「逻辑推理」且满档满正确率；其余维度无任何记录
        let sessions = (0..<5).map { qb(.logicReasoning, difficulty: 3, accuracy: 1.0, daysAgo: $0) }
        let profile = AppSkillProfile.compute(sessions: sessions)

        let logic = profile.categoryScores.first { $0.category == .logicalReasoning }!
        let memory = profile.categoryScores.first { $0.category == .memory }!

        #expect(logic.hasData)
        #expect(!memory.hasData)                 // 没练过 → 无数据（不再算成 35 拖低）
        #expect(logic.score >= 90)
        #expect(profile.overallInternalScore >= 90)  // 综合只由有数据维度决定
        #expect(abs(profile.coverage - 0.25) < 1e-9) // 4 维度中 1 个有数据
    }
}
