import Foundation
import Observation

@Observable
final class SyllogismEngine {
    let difficulty: Int
    let totalTrials: Int
    let timeLimitPerTrial: TimeInterval
    let startedAt: Date

    private(set) var currentTrialIndex: Int = 0
    private(set) var currentTrial: SyllogismTrial?
    private(set) var trialResults: [SyllogismTrialResult] = []
    private(set) var phase: Phase = .idle
    private(set) var trialStartTime: Date?
    var hintShownForCurrentTrial: Bool = false

    enum Phase: Equatable {
        case idle
        case presenting
        case feedback(correct: Bool, explanation: String)
        case completed
    }

    var isComplete: Bool { phase == .completed }

    var completionFraction: Double {
        Double(currentTrialIndex) / Double(max(totalTrials, 1))
    }

    var remainingTrials: Int {
        max(0, totalTrials - currentTrialIndex)
    }

    // MARK: - Init

    init(difficulty: Int, startedAt: Date = Date()) {
        self.difficulty = difficulty
        self.startedAt = startedAt

        switch difficulty {
        case 1:
            totalTrials = 12
            timeLimitPerTrial = 15
        case 2:
            totalTrials = 16
            timeLimitPerTrial = 12
        default:
            totalTrials = 20
            timeLimitPerTrial = 10
        }
    }

    // MARK: - Trial Generation

    func beginNextTrial() {
        guard currentTrialIndex < totalTrials else {
            phase = .completed
            return
        }

        let validRatio = Double.random(in: 0.40...0.60)
        let shouldBeValid = Double(validTrialCount) / Double(max(currentTrialIndex, 1)) < validRatio
            || (currentTrialIndex == 0 && Bool.random())

        let trial = generateTrial(shouldBeValid: shouldBeValid)
        currentTrial = trial
        hintShownForCurrentTrial = false
        trialStartTime = Date()
        phase = .presenting
    }

    func recordResponse(userSaysValid: Bool, at date: Date = Date()) {
        guard let trial = currentTrial, phase == .presenting else { return }

        let rt = trialStartTime.map { date.timeIntervalSince($0) }
        let correct = userSaysValid == trial.isValid
        let result = SyllogismTrialResult(
            trialIndex: currentTrialIndex,
            trial: trial,
            userAnswer: userSaysValid,
            isCorrect: correct,
            reactionTime: rt,
            usedHint: hintShownForCurrentTrial
        )
        trialResults.append(result)

        let explanation = correct ? "✓ " + trial.explanation : "✗ " + trial.explanation
        phase = .feedback(correct: correct, explanation: explanation)
    }

    func recordTimeout() {
        guard let trial = currentTrial, phase == .presenting else { return }

        let result = SyllogismTrialResult(
            trialIndex: currentTrialIndex,
            trial: trial,
            userAnswer: !trial.isValid, // wrong by default
            isCorrect: false,
            reactionTime: nil,
            usedHint: hintShownForCurrentTrial
        )
        trialResults.append(result)
        phase = .feedback(correct: false, explanation: "⏱ 超时 — " + trial.explanation)
    }

    func advanceToNext() {
        currentTrialIndex += 1
        currentTrial = nil
        trialStartTime = nil

        if currentTrialIndex >= totalTrials {
            phase = .completed
        } else {
            phase = .idle
        }
    }

    func computeMetrics() -> SyllogismMetrics {
        SyllogismMetrics.compute(from: trialResults, difficulty: difficulty)
    }

    // MARK: - Private

    private var validTrialCount: Int {
        trialResults.filter { $0.trial.isValid }.count
    }

    private func generateTrial(shouldBeValid: Bool) -> SyllogismTrial {
        let availableTypes = SyllogismType.available(for: difficulty)
        let validTypes = availableTypes.filter { $0.isValid }
        let invalidTypes = availableTypes.filter { !$0.isValid }

        let type: SyllogismType
        if shouldBeValid {
            type = validTypes.randomElement() ?? .categoricalValid
        } else {
            type = invalidTypes.randomElement() ?? .categoricalInvalid
        }

        return buildTrial(type: type)
    }

    private func buildTrial(type: SyllogismType) -> SyllogismTrial {
        let bank = SyllogismContentBank.relations
        switch type {
        case .categoricalValid:
            return buildCategoricalTrial(valid: true, bank: bank)
        case .categoricalInvalid:
            return buildCategoricalTrial(valid: false, bank: bank)
        case .modusPonens:
            return buildConditionalTrial(form: .modusPonens, bank: bank)
        case .modusTollens:
            return buildConditionalTrial(form: .modusTollens, bank: bank)
        case .affirmConsequent:
            return buildConditionalTrial(form: .affirmConsequent, bank: bank)
        case .denyAntecedent:
            return buildConditionalTrial(form: .denyAntecedent, bank: bank)
        case .quantifierTrap:
            return buildQuantifierTrapTrial(bank: bank)
        case .chainReasoning:
            return buildChainReasoningTrial(bank: bank)
        }
    }

    // MARK: - Categorical Syllogism

    private func buildCategoricalTrial(valid: Bool, bank: [ContentRelation]) -> SyllogismTrial {
        // Find 3 related relations to build a chain: S ⊂ M ⊂ P
        let shuffled = bank.shuffled()

        // Try to find a chain: A is B, B is C → A is C
        for r1 in shuffled {
            for r2 in shuffled where r2.id != r1.id {
                // Check if r1.category is a member of r2, or r2 has r1.category as member
                if r2.members.contains(r1.category) {
                    // r1.members ⊂ r1.category ⊂ r2.category
                    let s = r1.members.randomElement() ?? r1.members[0]
                    let m = r1.category
                    let p = r2.category

                    if valid {
                        return SyllogismTrial(
                            premises: ["所有\(m)都\(r2.relationVerb)\(p)的一种", "所有\(s)都\(r1.relationVerb)\(m)的一种"],
                            conclusion: "所以，所有\(s)都\(r2.relationVerb)\(p)的一种",
                            isValid: true,
                            type: .categoricalValid,
                            abstractForm: "所有M是P，所有S是M ∴ 所有S是P (AAA-1, 有效)",
                            explanation: "这是有效的三段论（Barbara）：如果所有M是P，所有S是M，则所有S是P。",
                            detailedExplanation: "这是经典的AAA-1格式（Barbara）三段论。中项M（\(m)）在大前提中作为主项被全称肯定，在小前提中也被全称肯定。因此结论可以有效推出。类比：如果所有的鱼都生活在水里，金鱼是鱼，那么金鱼生活在水里。",
                            hasUnverifiedPremise: !r1.verified || !r2.verified
                        )
                    } else {
                        // Invalid: undistributed middle — All P are M, All S are M ∴ All S are P
                        return SyllogismTrial(
                            premises: ["所有\(p)都\(r2.relationVerb)\(m)相关", "所有\(s)也都\(r1.relationVerb)\(m)相关"],
                            conclusion: "所以，所有\(s)都\(r2.relationVerb)\(p)的一种",
                            isValid: false,
                            type: .categoricalInvalid,
                            abstractForm: "所有P是M，所有S是M ∴ 所有S是P (AAA-2, 无效：未分配中项)",
                            explanation: "未分配中项谬误：两个事物同属于一个类别，不能说明它们互相属于。",
                            detailedExplanation: "这是未分配中项（undistributed middle）谬误。中项M（\(m)）在两个前提中都只是作为谓项出现，没有被全称肯定过。举例：'所有猫是动物，所有狗是动物'不能推出'所有狗是猫'。",
                            hasUnverifiedPremise: !r1.verified || !r2.verified
                        )
                    }
                }
            }
        }

        // Fallback with simple hardcoded trial
        return fallbackCategoricalTrial(valid: valid)
    }

    private func fallbackCategoricalTrial(valid: Bool) -> SyllogismTrial {
        if valid {
            return SyllogismTrial(
                premises: ["所有金属都是导体", "铜是金属"],
                conclusion: "所以，铜是导体",
                isValid: true,
                type: .categoricalValid,
                abstractForm: "所有M是P，S是M ∴ S是P",
                explanation: "有效推理：铜属于金属，金属都是导体，所以铜是导体。"
            )
        } else {
            return SyllogismTrial(
                premises: ["所有鸟都是恒温动物", "所有哺乳动物都是恒温动物"],
                conclusion: "所以，所有哺乳动物都是鸟",
                isValid: false,
                type: .categoricalInvalid,
                abstractForm: "所有A是C，所有B是C ∴ 所有B是A (无效)",
                explanation: "未分配中项：鸟和哺乳动物都是恒温动物，但它们不是同一类。"
            )
        }
    }

    // MARK: - Conditional Reasoning

    private func buildConditionalTrial(form: SyllogismType, bank: [ContentRelation]) -> SyllogismTrial {
        let r = bank.randomElement()!
        let member = r.members.randomElement() ?? r.members[0]

        let pClause = "一个事物\(r.relationVerb)\(member)"
        let qClause = "它\(r.relationVerb)\(r.category)的一种"

        switch form {
        case .modusPonens:
            return SyllogismTrial(
                premises: ["如果\(pClause)，那么\(qClause)", "\(member)确实\(r.relationVerb)\(member)"],
                conclusion: "所以，\(member)\(r.relationVerb)\(r.category)的一种",
                isValid: true,
                type: .modusPonens,
                abstractForm: "如果P则Q，P ∴ Q (肯定前件，有效)",
                explanation: "肯定前件（Modus Ponens）：前件为真时，后件必然为真。",
                detailedExplanation: "这是最基本的有效推理形式。如果'P→Q'为真，且P为真，则Q必然为真。这就像：'如果下雨，地面就会湿'。确实在下雨，所以地面一定是湿的。"
            )

        case .modusTollens:
            return SyllogismTrial(
                premises: ["如果\(pClause)，那么\(qClause)", "但该事物并非\(r.category)的一种"],
                conclusion: "所以，该事物不\(r.relationVerb)\(member)",
                isValid: true,
                type: .modusTollens,
                abstractForm: "如果P则Q，非Q ∴ 非P (否定后件，有效)",
                explanation: "否定后件（Modus Tollens）：如果后件为假，前件也必然为假。",
                detailedExplanation: "否定后件是有效推理：如果'P→Q'为真且Q为假，则P必然为假。类比：'如果下雨则地湿'，地面是干的，所以没有下雨。注意：这和'否定前件'不同，否定前件是无效的。"
            )

        case .affirmConsequent:
            return SyllogismTrial(
                premises: ["如果\(pClause)，那么\(qClause)", "已知该事物\(r.relationVerb)\(r.category)的一种"],
                conclusion: "所以，该事物一定\(r.relationVerb)\(member)",
                isValid: false,
                type: .affirmConsequent,
                abstractForm: "如果P则Q，Q ∴ P (肯定后件，无效)",
                explanation: "肯定后件谬误：知道Q为真不能反推P为真，因为Q可能有其他原因。",
                detailedExplanation: "这是一个常见谬误。知道结果为真不能反推原因。类比：'如果下雨则地湿'，地面是湿的，但地湿可能是洒水车经过，不一定是下雨。后件可能有多个充分条件。"
            )

        case .denyAntecedent:
            return SyllogismTrial(
                premises: ["如果\(pClause)，那么\(qClause)", "但该事物并非\(member)"],
                conclusion: "所以，该事物一定不\(r.relationVerb)\(r.category)的一种",
                isValid: false,
                type: .denyAntecedent,
                abstractForm: "如果P则Q，非P ∴ 非Q (否定前件，无效)",
                explanation: "否定前件谬误：前件为假时，后件不一定为假，可能有其他原因使Q为真。",
                detailedExplanation: "否定前件是无效推理。类比：'如果下雨则地湿'，没有下雨，但地面仍可能是湿的（比如刚洗过地）。前件为假不能推出后件为假。"
            )

        default:
            return fallbackCategoricalTrial(valid: true)
        }
    }

    // MARK: - Quantifier Trap

    private func buildQuantifierTrapTrial(bank: [ContentRelation]) -> SyllogismTrial {
        let r = bank.filter { $0.members.count >= 2 }.randomElement() ?? bank[0]
        let subset = Array(r.members.prefix(2))

        return SyllogismTrial(
            premises: ["有些\(r.category)具有特性X（如\(subset.joined(separator: "、"))）", "所有\(subset[0])都属于Z类别"],
            conclusion: "所以，所有\(r.category)都属于Z类别",
            isValid: false,
            type: .quantifierTrap,
            abstractForm: "有些A是B，所有B是C ∴ 所有A是C (量词偷换：有些≠所有，无效)",
            explanation: "量词陷阱：从\"有些A是B\"不能推出\"所有A是B\"。\"有些\"不等于\"所有\"。",
            detailedExplanation: "这里的关键错误在于量词偷换。前提说的是\"有些\(r.category)具有某特性\"，但结论却跳到了\"所有\(r.category)\"。\"有些\"只代表部分成员，不能等同于全部。这是日常推理中非常常见的错误。"
        )
    }

    // MARK: - Chain Reasoning

    private func buildChainReasoningTrial(bank: [ContentRelation]) -> SyllogismTrial {
        // A→B, B→C, C→D ∴ A→D (valid chain)
        let shuffled = bank.shuffled()
        guard shuffled.count >= 3 else {
            return fallbackCategoricalTrial(valid: true)
        }

        let r1 = shuffled[0]
        let r2 = shuffled[1]
        let r3 = shuffled[2]
        let a = r1.members.randomElement() ?? r1.members[0]
        let b = r1.category
        let c = r2.category
        let d = r3.category

        let valid = Bool.random()

        if valid {
            return SyllogismTrial(
                premises: [
                    "如果一个事物属于\(a)，那么它属于\(b)",
                    "如果一个事物属于\(b)，那么它属于\(c)",
                    "如果一个事物属于\(c)，那么它属于\(d)"
                ],
                conclusion: "所以，如果一个事物属于\(a)，那么它属于\(d)",
                isValid: true,
                type: .chainReasoning,
                abstractForm: "A→B, B→C, C→D ∴ A→D (假言连锁，有效)",
                explanation: "假言连锁（Hypothetical Syllogism）：如果A→B→C→D，则A→D是有效的。",
                detailedExplanation: "这是假言连锁推理：多个条件语句首尾相连，可以得出从第一个前件到最后一个后件的结论。就像多米诺骨牌：A推倒B，B推倒C，C推倒D，所以A可以间接推倒D。"
            )
        } else {
            return SyllogismTrial(
                premises: [
                    "如果一个事物属于\(a)，那么它属于\(b)",
                    "如果一个事物属于\(c)，那么它属于\(b)",
                    "如果一个事物属于\(c)，那么它属于\(d)"
                ],
                conclusion: "所以，如果一个事物属于\(a)，那么它属于\(d)",
                isValid: false,
                type: .chainReasoning,
                abstractForm: "A→B, C→B, C→D ∴ A→D (链条断裂，无效)",
                explanation: "链条断裂：A→B和C→B共享B，但A和C没有连接关系，不能推出A→D。",
                detailedExplanation: "看起来像连锁推理，但链条在中间断了。A→B和C→B都指向B，但这不意味着A和C有任何关系。就像两条路都通往同一个城市，但不代表这两条路的起点之间有直达路线。"
            )
        }
    }
}
