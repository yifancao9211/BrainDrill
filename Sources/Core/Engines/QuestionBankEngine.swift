import Foundation
import Observation

/// 自适应题库练习引擎：从题池中按「目标正确率 ~80%」的加权升降阶梯逐题选题。
/// 起始难度由调用方按能力 θ 给定；答对→难度小步上升，答错→难度大步下降（up:down≈1:4 → 收敛到 ~80% 正确率）。
@Observable
final class QuestionBankEngine {
    enum Phase: Equatable {
        case presenting
        case feedback(selectedIndex: Int, correct: Bool)
        case completed
    }

    struct Answer {
        let question: BankQuestion
        let selectedIndex: Int
        let isCorrect: Bool
        let reactionTime: TimeInterval
    }

    // 加权阶梯步长：答对 +up（变难），答错 −down（变易）。up/down = (1-p)/p，取 p≈0.8。
    static let stepUp = 0.25
    static let stepDown = 1.0

    let section: BankSection
    let timed: Bool
    let totalSeconds: Int
    let total: Int                 // 本场题量
    let startedAt: Date

    private let pool: [BankQuestion]
    private let weakTypes: Set<String>
    /// 逐题经验难度覆盖（轻量 IRT）：题 id → 难度估计（1–3，越大越难）。缺省回退到作者标注难度。
    private let difficultyOverrides: [String: Double]
    /// 综合出题时各板块的目标占比权重（如国考行测比例）。为空或仅含单板块时退化为纯难度选题。
    private let sectionWeights: [BankSection: Double]
    private(set) var currentDifficulty: Double
    private(set) var index: Int = 0
    private(set) var phase: Phase = .presenting
    private(set) var answers: [Answer] = []
    private(set) var currentQuestion: BankQuestion?
    private var questionStartedAt: Date

    init(
        pool: [BankQuestion],
        section: BankSection,
        targetCount: Int,
        startDifficulty: Double,
        weakTypes: Set<String> = [],
        difficultyOverrides: [String: Double] = [:],
        sectionWeights: [BankSection: Double] = [:],
        timed: Bool = false,
        totalSeconds: Int = 600,
        now: Date = Date()
    ) {
        self.pool = pool
        self.section = section
        self.weakTypes = weakTypes
        self.difficultyOverrides = difficultyOverrides
        self.sectionWeights = sectionWeights
        self.timed = timed
        self.totalSeconds = totalSeconds
        self.total = min(max(targetCount, 1), pool.count)
        self.currentDifficulty = min(max(startDifficulty, 1), 3)
        self.startedAt = now
        self.questionStartedAt = now
        self.currentQuestion = nil
        self.currentQuestion = pickNext(excluding: [])
    }

    /// 题目的有效难度：优先经验难度，否则作者标注。
    private func effectiveDifficulty(_ q: BankQuestion) -> Double {
        difficultyOverrides[q.id] ?? Double(q.difficulty)
    }

    var isComplete: Bool { phase == .completed }
    var completionFraction: Double { total > 0 ? Double(index) / Double(total) : 1 }
    var correctSoFar: Int { answers.filter { $0.isCorrect }.count }

    // MARK: - Actions

    func select(_ optionIndex: Int, at date: Date = Date()) {
        guard case .presenting = phase, let question = currentQuestion else { return }
        let correct = optionIndex == question.answerIndex
        let rt = max(0, date.timeIntervalSince(questionStartedAt))
        answers.append(Answer(question: question, selectedIndex: optionIndex, isCorrect: correct, reactionTime: rt))
        // 加权升降阶梯
        currentDifficulty = min(max(currentDifficulty + (correct ? Self.stepUp : -Self.stepDown), 1), 3)
        phase = .feedback(selectedIndex: optionIndex, correct: correct)
    }

    func advance(at date: Date = Date()) {
        guard !isComplete else { return }
        index += 1
        let answeredIDs = Set(answers.map(\.question.id))
        if index >= total {
            phase = .completed
            currentQuestion = nil
            return
        }
        let next = pickNext(excluding: answeredIDs)
        if next == nil {
            phase = .completed
            currentQuestion = nil
        } else {
            currentQuestion = next
            phase = .presenting
            questionStartedAt = date
        }
    }

    func forceComplete() {
        phase = .completed
        currentQuestion = nil
    }

    /// 从题池中挑一道：综合会话先按目标占比补「最欠配额」的板块，再在该板块内按难度阶梯挑；
    /// 单板块会话退化为纯难度选题。并列时优先薄弱题型，再按稳定顺序。
    private func pickNext(excluding: Set<String>) -> BankQuestion? {
        let candidates = pool.filter { !excluding.contains($0.id) }
        guard !candidates.isEmpty else { return nil }

        // 跨板块配额：仅当本场目标含多个板块、且候选里实际存在多个板块时启用。
        let presentSections = Set(candidates.map(\.section))
        let weighted = sectionWeights.filter { presentSections.contains($0.key) && $0.value > 0 }
        if weighted.count > 1 {
            let totalWeight = weighted.values.reduce(0, +)
            var served: [BankSection: Int] = [:]
            for a in answers { served[a.question.section, default: 0] += 1 }
            let totalServed = answers.count
            // 缺额 = 目标占比 ×(已出 +1) − 已出；取缺额最大、仍有候选的板块。
            let target = weighted.max { lhs, rhs in
                func deficit(_ s: BankSection, _ w: Double) -> Double {
                    w / totalWeight * Double(totalServed + 1) - Double(served[s] ?? 0)
                }
                let dl = deficit(lhs.key, lhs.value), dr = deficit(rhs.key, rhs.value)
                if abs(dl - dr) > 0.0001 { return dl < dr }
                return lhs.value < rhs.value          // 并列时偏向占比更高的板块
            }?.key
            if let target {
                return pickByDifficulty(candidates.filter { $0.section == target })
            }
        }
        return pickByDifficulty(candidates)
    }

    /// 在给定候选内挑有效难度最接近当前目标者；并列优先薄弱题型，再按稳定顺序。
    private func pickByDifficulty(_ candidates: [BankQuestion]) -> BankQuestion? {
        candidates.min { a, b in
            let da = abs(effectiveDifficulty(a) - currentDifficulty)
            let db = abs(effectiveDifficulty(b) - currentDifficulty)
            if abs(da - db) > 0.0001 { return da < db }
            let wa = weakTypes.contains(a.type) ? 0 : 1
            let wb = weakTypes.contains(b.type) ? 0 : 1
            if wa != wb { return wa < wb }
            return a.id < b.id
        }
    }

    // MARK: - Metrics

    func computeMetrics() -> BankPracticeMetrics {
        let total = answers.count
        let correct = answers.filter { $0.isCorrect }.count
        let accuracy = total > 0 ? Double(correct) / Double(total) : 0

        var perTypeCorrect: [String: Int] = [:]
        var perTypeTotal: [String: Int] = [:]
        for answer in answers {
            let key = answer.question.type
            perTypeTotal[key, default: 0] += 1
            if answer.isCorrect { perTypeCorrect[key, default: 0] += 1 }
        }

        let rts = answers.map(\.reactionTime).sorted()
        let medianRT: TimeInterval
        if rts.isEmpty {
            medianRT = 0
        } else if rts.count % 2 == 1 {
            medianRT = rts[rts.count / 2]
        } else {
            medianRT = (rts[rts.count / 2 - 1] + rts[rts.count / 2]) / 2
        }

        return BankPracticeMetrics(
            section: section,
            difficulty: sessionDifficulty(),
            totalQuestions: total,
            correctCount: correct,
            accuracy: accuracy,
            perTypeCorrect: perTypeCorrect,
            perTypeTotal: perTypeTotal,
            medianRT: medianRT,
            timed: timed
        )
    }

    /// 本场代表难度 = 作答题目难度均值四舍五入（无作答取当前难度）。
    private func sessionDifficulty() -> Int {
        guard !answers.isEmpty else { return min(max(Int(currentDifficulty.rounded()), 1), 3) }
        let avg = Double(answers.map { $0.question.difficulty }.reduce(0, +)) / Double(answers.count)
        return min(max(Int(avg.rounded()), 1), 3)
    }
}

// MARK: - Selection (保留：用于独立的近期去重/弱项加权测试与潜在复用)

/// 题目选取：优先未在近期出现过的题，并对薄弱题型加权，随机抽取 `count` 道。
enum QuestionSelector {
    static func pick(
        from pool: [BankQuestion],
        count: Int,
        recentFingerprints: Set<String>,
        weakTypes: Set<String>,
        targetDifficulty: Int? = nil,
        randomSource: () -> Double = { Double.random(in: 0..<1) }
    ) -> [BankQuestion] {
        guard !pool.isEmpty else { return [] }
        let fresh = pool.filter { !recentFingerprints.contains($0.fingerprint) }
        let candidates = fresh.count >= count ? fresh : pool

        func weight(_ q: BankQuestion) -> Double {
            var w = 1.0
            if weakTypes.contains(q.type) { w *= 2.0 }
            if let target = targetDifficulty {
                w *= 1.0 / Double(1 + abs(q.difficulty - target))
            }
            return w
        }

        var remaining = candidates
        var chosen: [BankQuestion] = []
        let wanted = min(count, remaining.count)
        for _ in 0..<wanted {
            let weights = remaining.map(weight)
            let totalWeight = weights.reduce(0, +)
            guard totalWeight > 0 else { break }
            var roll = randomSource() * totalWeight
            var pickedIndex = remaining.count - 1
            for (i, w) in weights.enumerated() {
                roll -= w
                if roll <= 0 { pickedIndex = i; break }
            }
            chosen.append(remaining.remove(at: pickedIndex))
        }
        return chosen
    }
}
