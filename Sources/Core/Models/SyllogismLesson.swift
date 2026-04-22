import Foundation

// MARK: - Lesson Model

struct SyllogismLesson: Identifiable {
    let id: Int  // lessonGroup number 1-13
    let title: String
    let difficulty: Int  // 1, 2, or 3
    let types: [SyllogismType]
    let cards: [LessonCard]

    struct LessonCard: Identifiable {
        let id: String
        let type: SyllogismType
        let typeName: String
        let logicForm: String
        let isValid: Bool
        let example: WorkedExample
        let whyExplanation: String
        let confusionWarning: String?
    }

    struct WorkedExample {
        let premises: [String]
        let conclusion: String
        let isValid: Bool
    }
}

// MARK: - Lesson Bank

enum SyllogismLessonBank {

    static let totalLessons = 13

    static func lesson(_ group: Int) -> SyllogismLesson {
        let types = SyllogismType.typesInLesson(group)
        let info = lessonInfo(group)
        let cards = types.map { cardFor($0) }
        return SyllogismLesson(id: group, title: info.title, difficulty: info.difficulty, types: types, cards: cards)
    }

    static func allLessons() -> [SyllogismLesson] {
        (1...totalLessons).map { lesson($0) }
    }

    static func lessonsForDifficulty(_ d: Int) -> [SyllogismLesson] {
        allLessons().filter { $0.difficulty == d }
    }

    /// Difficulty tier for unlock: L1-4 → 1, L5-9 → 2, L10-13 → 3
    static func requiredCompletedLessons(for group: Int) -> [Int] {
        switch group {
        case 1...4: return []
        case 5...9: return Array(1...4)
        case 10...13: return Array(1...9)
        default: return []
        }
    }

    // MARK: - Lesson Metadata

    private static func lessonInfo(_ group: Int) -> (title: String, difficulty: Int) {
        switch group {
        case 1:  return ("条件推理入门", 1)
        case 2:  return ("直言三段论基础", 1)
        case 3:  return ("\"或\"的逻辑", 1)
        case 4:  return ("因果≠相关", 1)
        case 5:  return ("条件推理进阶", 2)
        case 6:  return ("三段论变体", 2)
        case 7:  return ("量词陷阱", 2)
        case 8:  return ("链式推理与复合", 2)
        case 9:  return ("因果与统计谬误", 2)
        case 10: return ("高级形式逻辑", 3)
        case 11: return ("量词深水区", 3)
        case 12: return ("概率推理", 3)
        case 13: return ("论证结构谬误", 3)
        default: return ("未知", 1)
        }
    }

    // MARK: - Card Content

    private static func cardFor(_ type: SyllogismType) -> SyllogismLesson.LessonCard {
        let c = content(for: type)
        return SyllogismLesson.LessonCard(
            id: type.rawValue,
            type: type,
            typeName: type.displayName,
            logicForm: c.logicForm,
            isValid: type.isValid,
            example: c.example,
            whyExplanation: c.why,
            confusionWarning: c.confusion
        )
    }

    private struct CardContent {
        let logicForm: String
        let example: SyllogismLesson.WorkedExample
        let why: String
        let confusion: String?
    }

    // swiftlint:disable function_body_length cyclomatic_complexity
    private static func content(for type: SyllogismType) -> CardContent {
        switch type {

        // ── A. 命题逻辑 ──

        case .modusPonens:
            return CardContent(
                logicForm: "P→Q, P ∴ Q",
                example: .init(premises: ["如果下雨，地面就会湿", "确实在下雨"], conclusion: "所以，地面一定是湿的", isValid: true),
                why: "前件为真时，后件必然为真。这是最基本的有效推理。",
                confusion: "和「肯定后件」区分：知道Q为真不能反推P。地湿≠一定下过雨。"
            )

        case .affirmConsequent:
            return CardContent(
                logicForm: "P→Q, Q ∴ P",
                example: .init(premises: ["如果下雨，地面就会湿", "地面是湿的"], conclusion: "所以，一定下过雨", isValid: false),
                why: "后件为真不能反推前件。地湿可能是洒水车经过，不一定是下雨。",
                confusion: "和「肯定前件」区分：MP是知道P推Q（有效），AC是知道Q反推P（无效）。"
            )

        case .modusTollens:
            return CardContent(
                logicForm: "P→Q, ¬Q ∴ ¬P",
                example: .init(premises: ["如果下雨，地面就会湿", "地面是干的"], conclusion: "所以，没有下雨", isValid: true),
                why: "后件为假时，前件必然为假。如果结果没出现，原因一定不成立。",
                confusion: "和「否定前件」区分：MT是否定后件（有效），DA是否定前件（无效）。"
            )

        case .denyAntecedent:
            return CardContent(
                logicForm: "P→Q, ¬P ∴ ¬Q",
                example: .init(premises: ["如果下雨，地面就会湿", "没有下雨"], conclusion: "所以，地面一定是干的", isValid: false),
                why: "前件为假不能推出后件为假。没下雨，但地面可能因为洗地而湿。",
                confusion: "和「否定后件」区分：MT否定的是Q（有效），DA否定的是P（无效）。"
            )

        case .disjunctiveSyllogism:
            return CardContent(
                logicForm: "P∨Q, ¬P ∴ Q",
                example: .init(premises: ["小明在图书馆或在食堂", "小明不在图书馆"], conclusion: "所以，小明在食堂", isValid: true),
                why: "\"或\"意味着至少一个为真。排除一个，另一个必然为真。",
                confusion: "和「析取谬误」区分：DS排除一个选项，析取谬误是选了一个就否定另一个。"
            )

        case .disjunctiveFallacy:
            return CardContent(
                logicForm: "P∨Q, P ∴ ¬Q",
                example: .init(premises: ["小明在图书馆或在食堂", "小明在图书馆"], conclusion: "所以，小明不在食堂", isValid: false),
                why: "\"或\"是相容析取（两个可以同时为真），选了一个不能否定另一个。",
                confusion: "在日常语言中\"或\"常被理解为排他（只能选一个），但逻辑学中\"或\"允许两者都真。"
            )

        case .constructiveDilemma:
            return CardContent(
                logicForm: "(P→Q)∧(R→S), P∨R ∴ Q∨S",
                example: .init(premises: ["如果努力学习就能考好，如果找到好工作就能赚钱", "小明要么努力学习，要么找到好工作"], conclusion: "所以，小明要么考好，要么赚钱", isValid: true),
                why: "两个条件句加上前件的析取，可以推出后件的析取。",
                confusion: nil
            )

        case .biconditional:
            return CardContent(
                logicForm: "P↔Q, P ∴ Q",
                example: .init(premises: ["一个数是偶数当且仅当它能被2整除", "6是偶数"], conclusion: "所以，6能被2整除", isValid: true),
                why: "双条件意味着P和Q等价：P真则Q真，P假则Q假。",
                confusion: "和普通条件P→Q不同：双条件是双向的，反过来也成立。"
            )

        case .biconditionalValid:
            return CardContent(
                logicForm: "P↔Q, Q ∴ P",
                example: .init(premises: ["一个数是偶数当且仅当它能被2整除", "10能被2整除"], conclusion: "所以，10是偶数", isValid: true),
                why: "双条件的逆向也有效：因为P↔Q等价于(P→Q)∧(Q→P)。",
                confusion: "这在单向条件P→Q中是「肯定后件」谬误，但在双条件P↔Q中是有效的！"
            )

        // ── B. 直言三段论 ──

        case .categoricalValid:
            return CardContent(
                logicForm: "所有M是P, 所有S是M ∴ 所有S是P",
                example: .init(premises: ["所有哺乳动物都是恒温动物", "所有狗都是哺乳动物"], conclusion: "所以，所有狗都是恒温动物", isValid: true),
                why: "Barbara式（AAA-1）：中项M连接大项P和小项S，传递关系成立。",
                confusion: "和「未分配中项」区分：Barbara的中项在大前提中作主项被全称肯定。"
            )

        case .categoricalInvalid:
            return CardContent(
                logicForm: "所有P是M, 所有S是M ∴ 所有S是P",
                example: .init(premises: ["所有猫都是动物", "所有狗都是动物"], conclusion: "所以，所有狗都是猫", isValid: false),
                why: "未分配中项：M在两个前提中都只是谓项，没有被全称限定。",
                confusion: "看起来像三段论，但中项M没有被「分配」（全称限定），无法建立S和P的关系。"
            )

        case .celarent:
            return CardContent(
                logicForm: "没有M是P, 所有S是M ∴ 没有S是P",
                example: .init(premises: ["没有爬行动物是恒温动物", "所有蛇都是爬行动物"], conclusion: "所以，没有蛇是恒温动物", isValid: true),
                why: "Celarent式（EAE-1）：M和P无交集，S全属于M，所以S和P也无交集。",
                confusion: nil
            )

        case .darii:
            return CardContent(
                logicForm: "所有M是P, 有些S是M ∴ 有些S是P",
                example: .init(premises: ["所有金属都是导体", "有些材料是金属"], conclusion: "所以，有些材料是导体", isValid: true),
                why: "Darii式（AII-1）：部分S属于M，而所有M都是P，所以这部分S也是P。",
                confusion: "注意结论只能说「有些」，不能说「所有」。"
            )

        case .ferio:
            return CardContent(
                logicForm: "没有M是P, 有些S是M ∴ 有些S不是P",
                example: .init(premises: ["没有昆虫是哺乳动物", "有些节肢动物是昆虫"], conclusion: "所以，有些节肢动物不是哺乳动物", isValid: true),
                why: "Ferio式（EIO-1）：M和P无交集，部分S属于M，所以这部分S不属于P。",
                confusion: nil
            )

        case .illicitMajor:
            return CardContent(
                logicForm: "所有M是P, 有些S是M ∴ 所有S是P",
                example: .init(premises: ["所有金属都是导体", "有些材料是金属"], conclusion: "所以，所有材料都是导体", isValid: false),
                why: "大项不当周延：前提只说「有些S是M」，结论却跳到「所有S是P」。",
                confusion: "和Darii对比：Darii的结论是「有些S是P」（有效），这里改成「所有」就无效了。"
            )

        case .fourTerms:
            return CardContent(
                logicForm: "所有A是B₁, 所有B₂是C ∴ 所有A是C（B₁≠B₂）",
                example: .init(premises: ["所有银行都是金融机构", "所有河岸(bank)都靠近水源"], conclusion: "所以，所有金融机构都靠近水源", isValid: false),
                why: "四项谬误：中项在两个前提中含义不同（bank＝银行 vs bank＝河岸）。",
                confusion: "表面上看是标准三段论，但「中项」其实是两个不同概念。"
            )

        // ── C. 量词逻辑 ──

        case .quantifierTrap:
            return CardContent(
                logicForm: "有些A是B, 所有B是C ∴ 所有A是C",
                example: .init(premises: ["有些学生擅长数学", "所有擅长数学的人都能当工程师"], conclusion: "所以，所有学生都能当工程师", isValid: false),
                why: "量词偷换：从「有些」偷换成「所有」。有些≠所有。",
                confusion: "日常对话中常犯此错：看到几个例子就推广到全部。"
            )

        case .universalInstantiation:
            return CardContent(
                logicForm: "∀x P(x) ∴ P(a)",
                example: .init(premises: ["所有人都会死"], conclusion: "所以，苏格拉底会死", isValid: true),
                why: "全称实例化：全称命题对每一个个体都成立。",
                confusion: "反过来不行：从一个个体不能推出全称命题（那是存在泛化谬误）。"
            )

        case .existentialFallacy:
            return CardContent(
                logicForm: "P(a) ∴ ∀x P(x)",
                example: .init(premises: ["我认识的张三很聪明"], conclusion: "所以，所有人都很聪明", isValid: false),
                why: "存在泛化谬误：从一个特定个体推广到所有个体，没有依据。",
                confusion: "和「以偏概全」类似，但更侧重逻辑形式而非论证质量。"
            )

        case .quantifierNegation:
            return CardContent(
                logicForm: "¬∀x P(x) ≡ ∃x ¬P(x)",
                example: .init(premises: ["并非所有鸟都会飞"], conclusion: "所以，存在不会飞的鸟", isValid: true),
                why: "「不是所有」等价于「存在某些不是」。同理「不存在」等价于「所有都不是」。",
                confusion: "常见错误：把「并非所有A是B」理解为「所有A都不是B」。"
            )

        case .scopeAmbiguity:
            return CardContent(
                logicForm: "∀x∃y vs ∃y∀x",
                example: .init(premises: ["每个人都爱某个人"], conclusion: "这句话有两种理解：每人爱的可以是不同人 vs 所有人爱同一个人", isValid: false),
                why: "量词辖域歧义：量词的先后顺序影响语义。∀x∃y≠∃y∀x。",
                confusion: "日常语言中这种歧义非常常见，需要明确量词的作用范围。"
            )

        // ── D. 链式与复合推理 ──

        case .chainReasoning:
            return CardContent(
                logicForm: "P→Q, Q→R ∴ P→R",
                example: .init(premises: ["如果努力学习就能考上大学", "如果考上大学就能找到好工作"], conclusion: "所以，如果努力学习就能找到好工作", isValid: true),
                why: "假言连锁：条件链首尾相连，可以省略中间环节。",
                confusion: "链条必须首尾相连（A→B, B→C），如果是A→B, C→B则链条断裂。"
            )

        case .contraposition:
            return CardContent(
                logicForm: "P→Q ≡ ¬Q→¬P",
                example: .init(premises: ["如果是哺乳动物，则是恒温动物"], conclusion: "等价于：如果不是恒温动物，则不是哺乳动物", isValid: true),
                why: "逆否命题与原命题等价。否定后件并交换前后件。",
                confusion: "注意：逆命题(Q→P)和否命题(¬P→¬Q)都不等价于原命题！"
            )

        case .deMorgan:
            return CardContent(
                logicForm: "¬(P∧Q) ≡ ¬P∨¬Q",
                example: .init(premises: ["小明不是既会游泳又会骑车"], conclusion: "等价于：小明不会游泳或者不会骑车（至少一个不会）", isValid: true),
                why: "德摩根定律：否定合取等于析取否定，否定析取等于合取否定。",
                confusion: "¬(P∧Q)不是¬P∧¬Q（那意味着两个都不会，太强了）。"
            )

        case .absorption:
            return CardContent(
                logicForm: "P→Q ∴ P→(P∧Q)",
                example: .init(premises: ["如果下雨则路滑"], conclusion: "等价于：如果下雨，则下雨且路滑", isValid: true),
                why: "吸收律：如果P蕴含Q，那么P也蕴含P与Q的合取。",
                confusion: nil
            )

        // ── E. 因果与统计推理 ──

        case .correlationCausation:
            return CardContent(
                logicForm: "A与B相关 ∴ A导致B",
                example: .init(premises: ["冰淇淋销量和溺水人数正相关"], conclusion: "所以，吃冰淇淋导致溺水", isValid: false),
                why: "相关不等于因果。两者可能由第三变量（夏天/高温）同时驱动。",
                confusion: "和「倒果为因」区分：这里问题是根本没有因果关系，倒果为因是因果方向搞反。"
            )

        case .reverseCausation:
            return CardContent(
                logicForm: "A与B相关, A导致B ∴ 实际是B导致A",
                example: .init(premises: ["消防员数量越多的地区火灾越多"], conclusion: "所以，消防员导致了火灾", isValid: false),
                why: "倒果为因：因果方向搞反了。是火灾多所以配备更多消防员。",
                confusion: "和「相关≠因果」区分：倒因果至少承认有因果关系，只是方向反了。"
            )

        case .baseRateNeglect:
            return CardContent(
                logicForm: "P(A|B)高 ∴ P(B|A)也高",
                example: .init(premises: ["这个检测准确率99%", "某人检测阳性"], conclusion: "所以，此人99%概率患病", isValid: false),
                why: "基率忽略：忽略了患病的先验概率。如果患病率1/10000，阳性也大概率是假阳性。",
                confusion: "需要用贝叶斯定理：P(患病|阳性) = P(阳性|患病)×P(患病) / P(阳性)。"
            )

        case .gamblerFallacy:
            return CardContent(
                logicForm: "连续n次A ∴ 下次更可能¬A",
                example: .init(premises: ["硬币连续抛出5次正面"], conclusion: "所以，第6次更可能是反面", isValid: false),
                why: "赌徒谬误：独立事件的概率不受前次结果影响。每次仍是50%。",
                confusion: "直觉告诉我们「该平衡了」，但硬币没有记忆。"
            )

        case .conjunctionFallacy:
            return CardContent(
                logicForm: "P(A∧B) > P(A)",
                example: .init(premises: ["Linda是银行出纳的概率", "vs Linda是银行出纳且是女权运动者的概率"], conclusion: "大多数人认为后者更可能，但这违反概率公理", isValid: false),
                why: "合取谬误：联合事件的概率不可能大于单个事件的概率。P(A∧B) ≤ P(A)。",
                confusion: "描述越具体、越「像」，人们越觉得可能——这是代表性启发的陷阱。"
            )

        case .slipperySlope:
            return CardContent(
                logicForm: "A → B → C → … → 灾难",
                example: .init(premises: ["如果允许学生迟到5分钟", "他们就会迟到半小时，然后旷课，最终辍学"], conclusion: "所以，不能允许迟到5分钟", isValid: false),
                why: "滑坡谬误：假设一连串因果链条必然发生，但每个环节都没有必然性。",
                confusion: "有些滑坡论证有数据支持（如上瘾机制），关键看每个环节是否有证据。"
            )

        // ── F. 论证结构谬误 ──

        case .falseDilemma:
            return CardContent(
                logicForm: "只有A或B ∴ 如果¬A则B",
                example: .init(premises: ["你要么支持这个政策，要么就是反对国家发展"], conclusion: "不支持就是反对发展", isValid: false),
                why: "虚假二分：人为制造只有两个选项的假象，实际可能有第三种立场。",
                confusion: nil
            )

        case .circularReasoning:
            return CardContent(
                logicForm: "P因为Q, Q因为P",
                example: .init(premises: ["这本书畅销因为它是好书", "它是好书因为它畅销"], conclusion: "循环论证：结论被当作前提使用", isValid: false),
                why: "循环论证：论证的前提和结论互相依赖，没有提供独立的支持。",
                confusion: nil
            )

        case .equivocation:
            return CardContent(
                logicForm: "A₁是B, A₂是C ∴ B是C（A₁≠A₂但用了同一个词）",
                example: .init(premises: ["法律面前人人平等", "每个人的能力是不平等的"], conclusion: "所以法律是不合理的", isValid: false),
                why: "歧义谬误：\"平等\"在两个前提中含义不同（权利平等 vs 能力平等）。",
                confusion: "和「四项谬误」类似，但四项谬误专指三段论中的中项含义偷换。"
            )

        case .hastyGeneralization:
            return CardContent(
                logicForm: "少数样本 → 全称结论",
                example: .init(premises: ["我认识的三个上海人都很精明"], conclusion: "所以，上海人都很精明", isValid: false),
                why: "以偏概全：样本太小且不具代表性，不能推广到整个群体。",
                confusion: "和「存在泛化谬误」区别：以偏概全侧重样本不足，存在泛化侧重逻辑形式。"
            )

        case .compositionDivision:
            return CardContent(
                logicForm: "部分有X性质 ∴ 整体有X性质（或反过来）",
                example: .init(premises: ["这支球队的每个球员都很优秀"], conclusion: "所以，这支球队一定很强", isValid: false),
                why: "合成谬误：部分的性质不一定适用于整体。优秀球员组合不一定配合默契。",
                confusion: "分割谬误是反过来：整体性质不一定适用于部分（富国的每个人不一定富）。"
            )
        }
    }
    // swiftlint:enable function_body_length cyclomatic_complexity
}
