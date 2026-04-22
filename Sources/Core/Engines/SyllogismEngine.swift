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

    init(difficulty: Int, totalTrials: Int? = nil, startedAt: Date = Date()) {
        self.difficulty = difficulty
        self.startedAt = startedAt

        if let totalTrials {
            self.totalTrials = totalTrials
            self.timeLimitPerTrial = 15
        } else {
            switch difficulty {
            case 1:
                self.totalTrials = 12
                self.timeLimitPerTrial = 15
            case 2:
                self.totalTrials = 16
                self.timeLimitPerTrial = 12
            default:
                self.totalTrials = 20
                self.timeLimitPerTrial = 10
            }
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

    /// Optional weak-type weights for spaced repetition (set by coordinator)
    var weakTypeWeights: [SyllogismType: Double] = [:]

    private func generateTrial(shouldBeValid: Bool) -> SyllogismTrial {
        let availableTypes = SyllogismType.available(for: difficulty)
        let validTypes = availableTypes.filter { $0.isValid }
        let invalidTypes = availableTypes.filter { !$0.isValid }

        let candidates = shouldBeValid ? validTypes : invalidTypes
        let fallback: SyllogismType = shouldBeValid ? .categoricalValid : .categoricalInvalid

        // Weighted random selection: weak types get 2x probability
        let type = weightedRandom(from: candidates) ?? fallback
        return buildTrial(type: type)
    }

    private func weightedRandom(from types: [SyllogismType]) -> SyllogismType? {
        guard !types.isEmpty else { return nil }
        let weights = types.map { weakTypeWeights[$0, default: 1.0] }
        let total = weights.reduce(0, +)
        var roll = Double.random(in: 0..<total)
        for (i, w) in weights.enumerated() {
            roll -= w
            if roll < 0 { return types[i] }
        }
        return types.last
    }

    func buildTrial(type: SyllogismType) -> SyllogismTrial {
        let bank = SyllogismContentBank.relations
        switch type {
        // A. Propositional
        case .modusPonens, .modusTollens, .affirmConsequent, .denyAntecedent:
            return buildConditionalTrial(form: type, bank: bank)
        case .disjunctiveSyllogism:
            return buildDisjunctiveTrial(valid: true, bank: bank)
        case .disjunctiveFallacy:
            return buildDisjunctiveTrial(valid: false, bank: bank)
        case .constructiveDilemma:
            return buildConstructiveDilemmaTrial(bank: bank)
        case .biconditional:
            return buildBiconditionalTrial(forward: true, bank: bank)
        case .biconditionalValid:
            return buildBiconditionalTrial(forward: false, bank: bank)
        // B. Categorical
        case .categoricalValid:
            return buildCategoricalTrial(valid: true, bank: bank)
        case .categoricalInvalid:
            return buildCategoricalTrial(valid: false, bank: bank)
        case .celarent:
            return buildCelarentTrial(bank: bank)
        case .darii:
            return buildDariiTrial(bank: bank)
        case .ferio:
            return buildFerioTrial(bank: bank)
        case .illicitMajor:
            return buildIllicitMajorTrial(bank: bank)
        case .fourTerms:
            return buildFourTermsTrial()
        // C. Quantifier
        case .quantifierTrap:
            return buildQuantifierTrapTrial(bank: bank)
        case .universalInstantiation:
            return buildUniversalInstantiationTrial(bank: bank)
        case .existentialFallacy:
            return buildExistentialFallacyTrial(bank: bank)
        case .quantifierNegation:
            return buildQuantifierNegationTrial(bank: bank)
        case .scopeAmbiguity:
            return buildScopeAmbiguityTrial()
        // D. Chain & Compound
        case .chainReasoning:
            return buildChainReasoningTrial(bank: bank)
        case .contraposition:
            return buildContrapositionTrial(bank: bank)
        case .deMorgan:
            return buildDeMorganTrial(bank: bank)
        case .absorption:
            return buildAbsorptionTrial(bank: bank)
        // E. Causal & Statistical
        case .correlationCausation:
            return buildCausalFallacyTrial(type: .correlationCausation)
        case .reverseCausation:
            return buildCausalFallacyTrial(type: .reverseCausation)
        case .baseRateNeglect:
            return buildCausalFallacyTrial(type: .baseRateNeglect)
        case .gamblerFallacy:
            return buildCausalFallacyTrial(type: .gamblerFallacy)
        case .conjunctionFallacy:
            return buildCausalFallacyTrial(type: .conjunctionFallacy)
        case .slipperySlope:
            return buildCausalFallacyTrial(type: .slipperySlope)
        // F. Argument Structure
        case .falseDilemma:
            return buildArgumentFallacyTrial(type: .falseDilemma)
        case .circularReasoning:
            return buildArgumentFallacyTrial(type: .circularReasoning)
        case .equivocation:
            return buildArgumentFallacyTrial(type: .equivocation)
        case .hastyGeneralization:
            return buildArgumentFallacyTrial(type: .hastyGeneralization)
        case .compositionDivision:
            return buildArgumentFallacyTrial(type: .compositionDivision)
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

    func fallbackCategoricalTrial(valid: Bool) -> SyllogismTrial {
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

    // MARK: - New Trial Builders for expanded reasoning types

    // MARK: - B. Categorical extensions

    func buildCelarentTrial(bank: [ContentRelation]) -> SyllogismTrial {
        let r = bank.randomElement()!
        let m = r.category
        let s = r.members.randomElement()!
        let p = bank.filter { $0.id != r.id }.randomElement()?.category ?? "矿物"
        return SyllogismTrial(
            premises: ["没有\(m)是\(p)", "所有\(s)都是\(m)"],
            conclusion: "所以，没有\(s)是\(p)",
            isValid: true, type: .celarent,
            abstractForm: "没有M是P, 所有S是M ∴ 没有S是P (EAE-1, 有效)",
            explanation: "Celarent式：M和P无交集，S属于M，所以S和P也无交集。",
            detailedExplanation: "这是第一格的EAE式（Celarent）。大前提否定了M和P的关系，小前提将S归入M，因此S不可能是P。"
        )
    }

    func buildDariiTrial(bank: [ContentRelation]) -> SyllogismTrial {
        let r = bank.filter { $0.members.count >= 2 }.randomElement() ?? bank[0]
        let m = r.category
        let _ = r.members.randomElement()!
        return SyllogismTrial(
            premises: ["所有\(m)都需要能量", "有些生物是\(m)"],
            conclusion: "所以，有些生物需要能量",
            isValid: true, type: .darii,
            abstractForm: "所有M是P, 有些S是M ∴ 有些S是P (AII-1, 有效)",
            explanation: "Darii式：所有M是P，部分S是M，所以部分S也是P。",
            detailedExplanation: "注意结论只能说「有些」而非「所有」，因为小前提只保证部分S属于M。"
        )
    }

    func buildFerioTrial(bank: [ContentRelation]) -> SyllogismTrial {
        let r = bank.randomElement()!
        let m = r.category
        let p = bank.filter { $0.id != r.id }.randomElement()?.category ?? "矿物"
        return SyllogismTrial(
            premises: ["没有\(m)是\(p)", "有些事物是\(m)"],
            conclusion: "所以，有些事物不是\(p)",
            isValid: true, type: .ferio,
            abstractForm: "没有M是P, 有些S是M ∴ 有些S不是P (EIO-1, 有效)",
            explanation: "Ferio式：M和P无交集，部分S是M，所以这部分S不是P。"
        )
    }

    func buildIllicitMajorTrial(bank: [ContentRelation]) -> SyllogismTrial {
        let r = bank.filter { $0.members.count >= 2 }.randomElement() ?? bank[0]
        let m = r.category
        let _ = r.members[0]
        return SyllogismTrial(
            premises: ["所有\(m)都有共同特征X", "有些事物是\(m)"],
            conclusion: "所以，所有事物都有共同特征X",
            isValid: false, type: .illicitMajor,
            abstractForm: "所有M是P, 有些S是M ∴ 所有S是P (无效：大项不当周延)",
            explanation: "大项不当周延：前提只说「有些S是M」，结论却跳到「所有S是P」。",
            detailedExplanation: "和Darii对比：Darii的结论是「有些S是P」（有效），这里改成「所有」就无效了。量词从「有些」偷换成「所有」。"
        )
    }

    func buildFourTermsTrial() -> SyllogismTrial {
        let examples: [(p1: String, p2: String, conc: String, word: String)] = [
            ("所有银行(bank)都是金融机构", "所有河岸(bank)都靠近水源", "所以，所有金融机构都靠近水源", "bank"),
            ("所有明星都引人注目", "所有恒星(star)都是天体", "所以，所有引人注目的事物都是天体", "star/明星"),
            ("笔可以写字", "笔(筆)也是一种量词", "所以，量词可以写字", "笔"),
        ]
        let ex = examples.randomElement()!
        return SyllogismTrial(
            premises: [ex.p1, ex.p2],
            conclusion: ex.conc,
            isValid: false, type: .fourTerms,
            abstractForm: "所有A是B₁, 所有B₂是C ∴ 所有A是C (B₁≠B₂, 无效)",
            explanation: "四项谬误：「\(ex.word)」在两个前提中含义不同，实际有四个概念而非三个。",
            detailedExplanation: "三段论要求中项在两个前提中指同一概念。这里的中项是多义词，导致论证包含四个不同概念。"
        )
    }

    // MARK: - A. Propositional extensions

    func buildDisjunctiveTrial(valid: Bool, bank: [ContentRelation]) -> SyllogismTrial {
        let r = bank.randomElement()!
        let a = r.members.randomElement()!
        let _ = bank.filter { $0.id != r.id }.randomElement()?.members.randomElement() ?? "其他事物"

        if valid {
            return SyllogismTrial(
                premises: ["\(a)在A组或在B组", "\(a)不在A组"],
                conclusion: "所以，\(a)在B组",
                isValid: true, type: .disjunctiveSyllogism,
                abstractForm: "P∨Q, ¬P ∴ Q (析取三段论, 有效)",
                explanation: "析取三段论：排除一个选项，另一个必然成立。"
            )
        } else {
            return SyllogismTrial(
                premises: ["\(a)在A组或在B组", "\(a)在A组"],
                conclusion: "所以，\(a)不在B组",
                isValid: false, type: .disjunctiveFallacy,
                abstractForm: "P∨Q, P ∴ ¬Q (析取谬误, 无效)",
                explanation: "析取谬误：「或」是相容的，两者可以同时为真。选了一个不能否定另一个。"
            )
        }
    }

    func buildConstructiveDilemmaTrial(bank: [ContentRelation]) -> SyllogismTrial {
        let r1 = bank.randomElement()!
        let r2 = bank.filter { $0.id != r1.id }.randomElement() ?? r1
        let a = r1.members.randomElement()!
        let b = r1.category
        let c = r2.members.randomElement()!
        let d = r2.category
        return SyllogismTrial(
            premises: ["如果选择\(a)路线则会到达\(b)", "如果选择\(c)路线则会到达\(d)", "必须选择\(a)路线或\(c)路线"],
            conclusion: "所以，会到达\(b)或\(d)",
            isValid: true, type: .constructiveDilemma,
            abstractForm: "(P→Q)∧(R→S), P∨R ∴ Q∨S (构造性两难, 有效)",
            explanation: "构造性两难：两个条件句加上前件的析取，推出后件的析取。"
        )
    }

    func buildBiconditionalTrial(forward: Bool, bank: [ContentRelation]) -> SyllogismTrial {
        let r = bank.randomElement()!
        let a = r.members.randomElement()!
        let b = r.category
        if forward {
            return SyllogismTrial(
                premises: ["一个事物属于\(a)当且仅当它属于\(b)的子类", "该事物属于\(a)"],
                conclusion: "所以，该事物属于\(b)的子类",
                isValid: true, type: .biconditional,
                abstractForm: "P↔Q, P ∴ Q (双条件正向, 有效)",
                explanation: "双条件推理：P↔Q意味着P和Q等价，知道P就能推Q。"
            )
        } else {
            return SyllogismTrial(
                premises: ["一个事物属于\(a)当且仅当它属于\(b)的子类", "该事物属于\(b)的子类"],
                conclusion: "所以，该事物属于\(a)",
                isValid: true, type: .biconditionalValid,
                abstractForm: "P↔Q, Q ∴ P (双条件逆向, 有效)",
                explanation: "双条件的逆向也有效：P↔Q等价于(P→Q)∧(Q→P)。注意在单向条件中这是「肯定后件」谬误！"
            )
        }
    }

    // MARK: - C. Quantifier extensions

    func buildUniversalInstantiationTrial(bank: [ContentRelation]) -> SyllogismTrial {
        let r = bank.randomElement()!
        let member = r.members.randomElement()!
        return SyllogismTrial(
            premises: ["所有\(r.category)都具有特性X"],
            conclusion: "所以，\(member)（作为\(r.category)的一种）具有特性X",
            isValid: true, type: .universalInstantiation,
            abstractForm: "∀x P(x) ∴ P(a) (全称实例化, 有效)",
            explanation: "全称实例化：全称命题对每个个体都成立。"
        )
    }

    func buildExistentialFallacyTrial(bank: [ContentRelation]) -> SyllogismTrial {
        let r = bank.randomElement()!
        let member = r.members.randomElement()!
        return SyllogismTrial(
            premises: ["\(member)具有特性X"],
            conclusion: "所以，所有\(r.category)都具有特性X",
            isValid: false, type: .existentialFallacy,
            abstractForm: "P(a) ∴ ∀x P(x) (存在泛化谬误, 无效)",
            explanation: "存在泛化谬误：从一个特定个体推广到所有个体，缺乏依据。"
        )
    }

    func buildQuantifierNegationTrial(bank: [ContentRelation]) -> SyllogismTrial {
        let r = bank.randomElement()!
        let examples: [(premise: String, conclusion: String)] = [
            ("并非所有\(r.category)都具有特性Y", "存在某些\(r.category)不具有特性Y"),
            ("不存在具有特性Z的\(r.category)", "所有\(r.category)都不具有特性Z"),
        ]
        let ex = examples.randomElement()!
        return SyllogismTrial(
            premises: [ex.premise],
            conclusion: "等价于：\(ex.conclusion)",
            isValid: true, type: .quantifierNegation,
            abstractForm: "¬∀x P(x) ≡ ∃x ¬P(x) (量词否定, 有效)",
            explanation: "量词否定：「不是所有」等价于「存在某些不是」。"
        )
    }

    func buildScopeAmbiguityTrial() -> SyllogismTrial {
        let examples: [(text: String, reading1: String, reading2: String)] = [
            ("每个学生都交了一篇论文", "每个学生各交了一篇(不同的)论文", "所有学生交了同一篇论文"),
            ("每个人都爱某个人", "每个人各爱不同的人", "所有人爱同一个人"),
        ]
        let ex = examples.randomElement()!
        return SyllogismTrial(
            premises: [ex.text],
            conclusion: "这句话有歧义：可能是\"\(ex.reading1)\"或\"\(ex.reading2)\"",
            isValid: false, type: .scopeAmbiguity,
            abstractForm: "∀x∃y P(x,y) vs ∃y∀x P(x,y) (量词辖域歧义)",
            explanation: "量词辖域歧义：量词的先后顺序影响语义，∀x∃y ≠ ∃y∀x。"
        )
    }

    // MARK: - D. Compound extensions

    func buildContrapositionTrial(bank: [ContentRelation]) -> SyllogismTrial {
        let r = bank.randomElement()!
        let a = r.members.randomElement()!
        let b = r.category
        return SyllogismTrial(
            premises: ["如果是\(a)，则属于\(b)"],
            conclusion: "等价于：如果不属于\(b)，则不是\(a)",
            isValid: true, type: .contraposition,
            abstractForm: "P→Q ≡ ¬Q→¬P (逆否命题, 有效)",
            explanation: "逆否命题与原命题等价。注意：逆命题(Q→P)不等价于原命题！"
        )
    }

    func buildDeMorganTrial(bank: [ContentRelation]) -> SyllogismTrial {
        let r = bank.filter { $0.members.count >= 2 }.randomElement() ?? bank[0]
        let a = r.members[0]
        let b = r.members[1]
        let useAnd = Bool.random()
        if useAnd {
            return SyllogismTrial(
                premises: ["某事物不是既属于\(a)又属于\(b)"],
                conclusion: "等价于：该事物不属于\(a)或不属于\(b)（至少一个不属于）",
                isValid: true, type: .deMorgan,
                abstractForm: "¬(P∧Q) ≡ ¬P∨¬Q (德摩根定律, 有效)",
                explanation: "德摩根定律：否定合取等于析取否定。"
            )
        } else {
            return SyllogismTrial(
                premises: ["某事物既不属于\(a)也不属于\(b)"],
                conclusion: "等价于：该事物不属于\(a)和\(b)中的任何一个",
                isValid: true, type: .deMorgan,
                abstractForm: "¬P∧¬Q ≡ ¬(P∨Q) (德摩根定律, 有效)",
                explanation: "德摩根定律：合取否定等于否定析取。"
            )
        }
    }

    func buildAbsorptionTrial(bank: [ContentRelation]) -> SyllogismTrial {
        let r = bank.randomElement()!
        let a = r.members.randomElement()!
        let b = r.category
        return SyllogismTrial(
            premises: ["如果是\(a)则属于\(b)"],
            conclusion: "等价于：如果是\(a)，则它是\(a)且属于\(b)",
            isValid: true, type: .absorption,
            abstractForm: "P→Q ∴ P→(P∧Q) (吸收律, 有效)",
            explanation: "吸收律：如果P蕴含Q，那么P也蕴含P与Q的合取。"
        )
    }

    // MARK: - E. Causal & Statistical

    func buildCausalFallacyTrial(type: SyllogismType) -> SyllogismTrial {
        switch type {
        case .correlationCausation:
            let examples: [(p: String, c: String, explain: String)] = [
                ("冰淇淋销量与溺水事故数正相关", "吃冰淇淋导致溺水", "两者都由夏天高温驱动，没有因果关系"),
                ("拥有游泳池的家庭孩子成绩更好", "游泳池提高了孩子成绩", "游泳池反映了家庭经济水平，经济水平才是影响因素"),
            ]
            let ex = examples.randomElement()!
            return SyllogismTrial(premises: [ex.p], conclusion: ex.c, isValid: false, type: .correlationCausation,
                abstractForm: "A与B相关 ∴ A导致B (无效)", explanation: "相关≠因果：\(ex.explain)")

        case .reverseCausation:
            let examples: [(p: String, c: String)] = [
                ("消防员多的地区火灾也多", "消防员导致火灾（实际是火灾多→配更多消防员）"),
                ("医院越多的城市死亡率越高", "医院导致死亡（实际是人口多→医院多且死亡数多）"),
            ]
            let ex = examples.randomElement()!
            return SyllogismTrial(premises: [ex.p], conclusion: ex.c, isValid: false, type: .reverseCausation,
                abstractForm: "A与B相关 ∴ A导致B (实际B导致A, 无效)", explanation: "倒果为因：因果方向搞反了。")

        case .baseRateNeglect:
            return SyllogismTrial(
                premises: ["某疾病患病率为1/10000", "检测准确率99%", "某人检测阳性"],
                conclusion: "此人99%概率患病", isValid: false, type: .baseRateNeglect,
                abstractForm: "P(+|病)高 ∴ P(病|+)也高 (忽略基率, 无效)",
                explanation: "基率忽略：患病率极低时，即使检测准确率99%，阳性结果大概率是假阳性。需用贝叶斯定理计算。")

        case .gamblerFallacy:
            let examples: [(p: String, c: String)] = [
                ("硬币连续5次正面", "第6次更可能是反面"),
                ("轮盘连续出了8次红色", "下一次更可能出黑色"),
            ]
            let ex = examples.randomElement()!
            return SyllogismTrial(premises: [ex.p], conclusion: ex.c, isValid: false, type: .gamblerFallacy,
                abstractForm: "连续n次A ∴ 下次更可能¬A (无效)", explanation: "赌徒谬误：独立事件的概率不受前次结果影响。")

        case .conjunctionFallacy:
            return SyllogismTrial(
                premises: ["Linda是哲学专业毕业，关心社会公正问题"],
                conclusion: "Linda是银行出纳且是女权运动者的概率 > 她仅是银行出纳的概率",
                isValid: false, type: .conjunctionFallacy,
                abstractForm: "P(A∧B) > P(A) (违反概率公理, 无效)",
                explanation: "合取谬误：联合事件概率不可能大于单个事件概率。描述越具体不等于越可能。")

        case .slipperySlope:
            let examples: [(p: String, c: String)] = [
                ("如果允许学生迟到5分钟", "他们就会迟到30分钟→旷课→辍学"),
                ("如果降低一点环保标准", "企业就会大量排污→生态崩溃→人类灭亡"),
            ]
            let ex = examples.randomElement()!
            return SyllogismTrial(premises: [ex.p], conclusion: ex.c, isValid: false, type: .slipperySlope,
                abstractForm: "A→B→C→…→灾难 (每步无必然性, 无效)", explanation: "滑坡谬误：假设因果链条必然发生，但每个环节都缺乏必然性。")

        default:
            return fallbackCategoricalTrial(valid: false)
        }
    }

    // MARK: - F. Argument Structure

    func buildArgumentFallacyTrial(type: SyllogismType) -> SyllogismTrial {
        switch type {
        case .falseDilemma:
            let examples: [(p: String, c: String)] = [
                ("你要么支持这个政策", "否则你就是反对国家发展（忽略了中间立场）"),
                ("要么全力加班", "否则你就是不上进（忽略了工作生活平衡）"),
            ]
            let ex = examples.randomElement()!
            return SyllogismTrial(premises: [ex.p], conclusion: ex.c, isValid: false, type: .falseDilemma,
                abstractForm: "只有A或B (实际还有C, D…, 无效)", explanation: "虚假二分：人为制造只有两个选项的假象。")

        case .circularReasoning:
            let examples: [(p1: String, p2: String)] = [
                ("这本书畅销因为写得好", "写得好因为它畅销"),
                ("他是对的因为他值得信任", "他值得信任因为他总是对的"),
            ]
            let ex = examples.randomElement()!
            return SyllogismTrial(premises: [ex.p1, ex.p2], conclusion: "结论隐含在前提中，形成循环",
                isValid: false, type: .circularReasoning,
                abstractForm: "P因为Q, Q因为P (循环, 无效)", explanation: "循环论证：前提和结论互相依赖。")

        case .equivocation:
            let examples: [(p1: String, p2: String, c: String, word: String)] = [
                ("法律面前人人平等", "人的能力是不平等的", "法律不合理", "平等"),
                ("人生苦短", "这杯咖啡苦", "人生像咖啡", "苦"),
            ]
            let ex = examples.randomElement()!
            return SyllogismTrial(premises: [ex.p1, ex.p2], conclusion: ex.c, isValid: false, type: .equivocation,
                abstractForm: "A₁是B, A₂是C ∴ B是C (A₁≠A₂, 无效)", explanation: "歧义谬误：「\(ex.word)」在两个前提中含义不同。")

        case .hastyGeneralization:
            let examples: [(p: String, c: String)] = [
                ("我认识的三个上海人都很精明", "上海人都很精明"),
                ("我用过两次这个品牌都坏了", "这个品牌质量都很差"),
            ]
            let ex = examples.randomElement()!
            return SyllogismTrial(premises: [ex.p], conclusion: ex.c, isValid: false, type: .hastyGeneralization,
                abstractForm: "少数样本→全称结论 (无效)", explanation: "以偏概全：样本太小且不具代表性。")

        case .compositionDivision:
            let examples: [(p: String, c: String, dir: String)] = [
                ("这支球队每个球员都很优秀", "这支球队一定很强", "合成"),
                ("这个国家很富有", "这个国家的每个人都很富有", "分割"),
            ]
            let ex = examples.randomElement()!
            return SyllogismTrial(premises: [ex.p], conclusion: ex.c, isValid: false, type: .compositionDivision,
                abstractForm: "部分性质→整体性质 (或反过来, 无效)", explanation: "\(ex.dir)谬误：部分性质不等于整体性质。")

        default:
            return fallbackCategoricalTrial(valid: false)
        }
    }
}
