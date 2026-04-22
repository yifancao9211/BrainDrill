import Foundation

// MARK: - Content Word Bank

enum ContentDomain: String, Codable, CaseIterable {
    case biology, physics, chemistry, geography
    case politics, economics, sociology
    case psychology, law, publicHealth
    case education, techEthics
}

struct ContentRelation: Codable, Identifiable {
    let id: String
    let category: String
    let members: [String]
    let relationVerb: String      // "是" / "属于" / "包含"
    let verified: Bool
    let domain: ContentDomain

    init(category: String, members: [String], relationVerb: String = "是", verified: Bool = true, domain: ContentDomain) {
        self.id = "\(domain.rawValue)_\(category)"
        self.category = category
        self.members = members
        self.relationVerb = relationVerb
        self.verified = verified
        self.domain = domain
    }
}

enum SyllogismContentBank {
    static let relations: [ContentRelation] = biology + physics + geography + politics + economics + sociology + psychology + law + publicHealth + education + techEthics

    // MARK: - Biology
    private static let biology: [ContentRelation] = [
        ContentRelation(category: "哺乳动物", members: ["狗", "猫", "鲸鱼", "蝙蝠", "人类", "海豚"], domain: .biology),
        ContentRelation(category: "恒温动物", members: ["哺乳动物", "鸟类"], domain: .biology),
        ContentRelation(category: "脊椎动物", members: ["哺乳动物", "鸟类", "爬行动物", "两栖动物", "鱼类"], domain: .biology),
        ContentRelation(category: "真核生物", members: ["动物", "植物", "真菌"], domain: .biology),
        ContentRelation(category: "被子植物", members: ["玫瑰", "水稻", "小麦", "苹果树"], domain: .biology),
        ContentRelation(category: "有细胞壁的生物", members: ["植物", "真菌", "细菌"], domain: .biology),
        ContentRelation(category: "需要氧气的生物", members: ["哺乳动物", "鸟类", "大多数真菌"], relationVerb: "是", domain: .biology),
        ContentRelation(category: "能进行光合作用的生物", members: ["植物", "蓝藻", "部分原生生物"], domain: .biology),
    ]

    // MARK: - Physics
    private static let physics: [ContentRelation] = [
        ContentRelation(category: "导体", members: ["铜", "铁", "铝", "金", "银", "石墨"], domain: .physics),
        ContentRelation(category: "金属", members: ["铜", "铁", "铝", "金", "银", "钠"], domain: .physics),
        ContentRelation(category: "绝缘体", members: ["橡胶", "玻璃", "陶瓷", "干燥木材"], domain: .physics),
        ContentRelation(category: "可再生能源", members: ["太阳能", "风能", "水力发电", "地热能"], domain: .physics),
        ContentRelation(category: "电磁波", members: ["可见光", "红外线", "紫外线", "X射线", "微波"], domain: .physics),
        ContentRelation(category: "基本力", members: ["引力", "电磁力", "强核力", "弱核力"], domain: .physics),
    ]

    // MARK: - Geography
    private static let geography: [ContentRelation] = [
        ContentRelation(category: "亚洲国家", members: ["中国", "日本", "印度", "韩国", "泰国"], domain: .geography),
        ContentRelation(category: "欧洲国家", members: ["法国", "德国", "英国", "意大利", "西班牙"], domain: .geography),
        ContentRelation(category: "内陆国家", members: ["蒙古", "瑞士", "奥地利", "老挝", "玻利维亚"], domain: .geography),
        ContentRelation(category: "岛国", members: ["日本", "英国", "冰岛", "马达加斯加", "新西兰"], domain: .geography),
    ]

    // MARK: - Politics
    private static let politics: [ContentRelation] = [
        ContentRelation(category: "联合国安理会常任理事国", members: ["中国", "美国", "俄罗斯", "英国", "法国"], domain: .politics),
        ContentRelation(category: "三权分立的组成部分", members: ["立法权", "行政权", "司法权"], domain: .politics),
        ContentRelation(category: "基本人权类型", members: ["生命权", "自由权", "财产权", "受教育权"], domain: .politics),
        ContentRelation(category: "政府职能", members: ["公共服务", "经济调节", "市场监管", "社会管理"], domain: .politics),
        ContentRelation(category: "国际组织", members: ["联合国", "世界贸易组织", "国际货币基金组织", "世界卫生组织"], domain: .politics),
        ContentRelation(category: "选举制度类型", members: ["多数制", "比例代表制", "混合制"], domain: .politics),
        ContentRelation(category: "主权国家的要素", members: ["人民", "领土", "政府", "主权"], domain: .politics),
    ]

    // MARK: - Economics
    private static let economics: [ContentRelation] = [
        ContentRelation(category: "GDP的组成部分", members: ["消费", "投资", "政府支出", "净出口"], domain: .economics),
        ContentRelation(category: "市场失灵的表现", members: ["垄断", "外部性", "信息不对称", "公共品供给不足"], domain: .economics),
        ContentRelation(category: "紧缩性货币政策的手段", members: ["加息", "提高准备金率", "公开市场卖出"], domain: .economics),
        ContentRelation(category: "生产要素", members: ["劳动", "资本", "土地", "企业家才能"], domain: .economics),
        ContentRelation(category: "机会成本的特征", members: ["放弃的最高价值选择", "隐性成本的一种"], relationVerb: "是", domain: .economics),
        ContentRelation(category: "通货膨胀的原因", members: ["需求拉动", "成本推动", "货币超发"], domain: .economics),
        ContentRelation(category: "贸易壁垒", members: ["关税", "配额", "技术标准", "反倾销税"], domain: .economics),
        ContentRelation(category: "金融市场类型", members: ["股票市场", "债券市场", "外汇市场", "期货市场"], domain: .economics),
    ]

    // MARK: - Sociology
    private static let sociology: [ContentRelation] = [
        ContentRelation(category: "社会分层的维度", members: ["收入", "教育", "职业声望", "权力"], domain: .sociology),
        ContentRelation(category: "初级社会化的场所", members: ["家庭"], domain: .sociology),
        ContentRelation(category: "社会控制的手段", members: ["法律", "道德", "舆论", "宗教"], domain: .sociology),
        ContentRelation(category: "社会流动类型", members: ["代际流动", "代内流动", "水平流动", "垂直流动"], domain: .sociology),
        ContentRelation(category: "社会组织类型", members: ["正式组织", "非正式组织", "志愿组织"], domain: .sociology),
        ContentRelation(category: "城市化的后果", members: ["人口密集", "匿名性增强", "社会流动加快"], relationVerb: "包含", verified: true, domain: .sociology),
    ]

    // MARK: - Psychology
    private static let psychology: [ContentRelation] = [
        ContentRelation(category: "认知偏差", members: ["确认偏误", "锚定效应", "可得性启发", "框架效应", "后见之明偏差"], domain: .psychology),
        ContentRelation(category: "大五人格特质", members: ["开放性", "责任心", "外倾性", "宜人性", "神经质"], domain: .psychology),
        ContentRelation(category: "马斯洛需求层次", members: ["生理需求", "安全需求", "社交需求", "尊重需求", "自我实现"], domain: .psychology),
        ContentRelation(category: "经典条件反射的要素", members: ["无条件刺激", "无条件反应", "条件刺激", "条件反应"], domain: .psychology),
        ContentRelation(category: "记忆类型", members: ["感觉记忆", "短时记忆", "长时记忆"], domain: .psychology),
        ContentRelation(category: "情绪的基本类型", members: ["快乐", "悲伤", "愤怒", "恐惧", "厌恶", "惊讶"], domain: .psychology),
        ContentRelation(category: "学习理论流派", members: ["行为主义", "认知主义", "建构主义", "人本主义"], domain: .psychology),
        ContentRelation(category: "防御机制", members: ["压抑", "投射", "合理化", "否认", "升华"], domain: .psychology),
    ]

    // MARK: - Law
    private static let law: [ContentRelation] = [
        ContentRelation(category: "刑罚的种类", members: ["管制", "拘役", "有期徒刑", "无期徒刑", "死刑"], domain: .law),
        ContentRelation(category: "合同成立的要件", members: ["要约", "承诺", "合意"], domain: .law),
        ContentRelation(category: "民事权利", members: ["物权", "债权", "知识产权", "人身权"], domain: .law),
        ContentRelation(category: "法律渊源", members: ["宪法", "法律", "行政法规", "地方性法规", "司法解释"], domain: .law),
        ContentRelation(category: "犯罪构成要件", members: ["犯罪主体", "犯罪客体", "犯罪主观方面", "犯罪客观方面"], domain: .law),
        ContentRelation(category: "诉讼类型", members: ["民事诉讼", "刑事诉讼", "行政诉讼"], domain: .law),
    ]

    // MARK: - Public Health
    private static let publicHealth: [ContentRelation] = [
        ContentRelation(category: "慢性病的风险因素", members: ["吸烟", "久坐", "高盐饮食", "肥胖", "过量饮酒"], domain: .publicHealth),
        ContentRelation(category: "传染病传播途径", members: ["飞沫传播", "接触传播", "血液传播", "母婴传播"], domain: .publicHealth),
        ContentRelation(category: "公共卫生干预措施", members: ["疫苗接种", "健康教育", "环境卫生", "疾病筛查"], domain: .publicHealth),
        ContentRelation(category: "世界卫生组织确认的致癌物", members: ["烟草", "石棉", "苯", "甲醛"], domain: .publicHealth),
        ContentRelation(category: "营养素类型", members: ["碳水化合物", "蛋白质", "脂肪", "维生素", "矿物质", "水"], domain: .publicHealth),
    ]

    // MARK: - Education
    private static let education: [ContentRelation] = [
        ContentRelation(category: "布鲁姆认知层次", members: ["记忆", "理解", "应用", "分析", "评价", "创造"], domain: .education),
        ContentRelation(category: "教学评估类型", members: ["形成性评估", "总结性评估", "诊断性评估"], domain: .education),
        ContentRelation(category: "多元智能类型", members: ["语言智能", "逻辑数学智能", "空间智能", "身体运动智能"], domain: .education),
    ]

    // MARK: - Tech Ethics
    private static let techEthics: [ContentRelation] = [
        ContentRelation(category: "AI伦理的关注点", members: ["算法偏见", "隐私侵犯", "透明度缺失", "责任归属不明"], domain: .techEthics),
        ContentRelation(category: "数据隐私原则", members: ["知情同意", "最小化收集", "目的限制", "数据安全"], domain: .techEthics),
        ContentRelation(category: "网络安全威胁类型", members: ["钓鱼攻击", "勒索软件", "DDoS攻击", "社会工程攻击"], domain: .techEthics),
        ContentRelation(category: "信息伦理问题", members: ["虚假信息", "信息茧房", "数字鸿沟", "网络欺凌"], domain: .techEthics),
    ]
}

// MARK: - Syllogism Types

enum SyllogismTypeCategory: String, Codable, CaseIterable, Identifiable {
    case propositional      // 命题逻辑
    case categorical        // 直言三段论
    case quantifier         // 量词逻辑
    case compound           // 链式与复合推理
    case causalStatistical  // 因果与统计推理
    case argumentStructure  // 论证结构谬误

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .propositional:     "命题逻辑"
        case .categorical:       "直言三段论"
        case .quantifier:        "量词逻辑"
        case .compound:          "链式与复合推理"
        case .causalStatistical: "因果与统计推理"
        case .argumentStructure: "论证结构谬误"
        }
    }
}

enum SyllogismType: String, Codable, CaseIterable {

    // ── A. 命题逻辑 (Propositional Logic) ──
    case modusPonens            // 肯定前件 ✓
    case modusTollens           // 否定后件 ✓
    case affirmConsequent       // 肯定后件 ✗
    case denyAntecedent         // 否定前件 ✗
    case disjunctiveSyllogism   // 析取三段论 ✓
    case disjunctiveFallacy     // 析取谬误 ✗
    case constructiveDilemma    // 构造性两难 ✓
    case biconditional          // 双条件推理 ✓
    case biconditionalValid     // 双条件逆向 ✓ (P↔Q, Q ∴ P)

    // ── B. 直言三段论 (Categorical Syllogisms) ──
    case categoricalValid       // Barbara AAA-1 ✓
    case categoricalInvalid     // 未分配中项 ✗
    case celarent               // Celarent EAE-1 ✓
    case darii                  // Darii AII-1 ✓
    case ferio                  // Ferio EIO-1 ✓
    case illicitMajor           // 大项不当周延 ✗
    case fourTerms              // 四项谬误 ✗

    // ── C. 量词逻辑 (Quantifier Logic) ──
    case quantifierTrap         // 量词偷换 ✗
    case universalInstantiation // 全称实例化 ✓
    case existentialFallacy     // 存在泛化谬误 ✗
    case quantifierNegation     // 量词否定 ✓
    case scopeAmbiguity         // 量词辖域歧义 (判断歧义)

    // ── D. 链式与复合推理 (Chain & Compound) ──
    case chainReasoning         // 假言连锁 ✓
    case contraposition         // 逆否命题 ✓
    case deMorgan               // 德摩根定律 ✓
    case absorption             // 吸收律 ✓

    // ── E. 因果与统计推理 (Causal & Statistical) ──
    case correlationCausation   // 相关≠因果 ✗
    case reverseCausation       // 倒果为因 ✗
    case baseRateNeglect        // 基率忽略 ✗
    case gamblerFallacy         // 赌徒谬误 ✗
    case conjunctionFallacy     // 合取谬误 ✗
    case slipperySlope          // 滑坡谬误 ✗

    // ── F. 论证结构谬误 (Argument Structure) ──
    case falseDilemma           // 虚假二分 ✗
    case circularReasoning      // 循环论证 ✗
    case equivocation           // 歧义谬误 ✗
    case hastyGeneralization    // 以偏概全 ✗
    case compositionDivision    // 合成/分割谬误 ✗

    // MARK: - Properties

    var isValid: Bool {
        switch self {
        // Valid
        case .modusPonens, .modusTollens, .disjunctiveSyllogism,
             .constructiveDilemma, .biconditional, .biconditionalValid,
             .categoricalValid, .celarent, .darii, .ferio,
             .universalInstantiation, .quantifierNegation,
             .chainReasoning, .contraposition, .deMorgan, .absorption:
            return true
        // Invalid / Fallacy
        case .affirmConsequent, .denyAntecedent, .disjunctiveFallacy,
             .categoricalInvalid, .illicitMajor, .fourTerms,
             .quantifierTrap, .existentialFallacy,
             .correlationCausation, .reverseCausation, .baseRateNeglect,
             .gamblerFallacy, .conjunctionFallacy, .slipperySlope,
             .falseDilemma, .circularReasoning, .equivocation,
             .hastyGeneralization, .compositionDivision:
            return false
        // Ambiguous (shown as "判断歧义" — special handling)
        case .scopeAmbiguity:
            return false // treated as fallacy for training purposes
        }
    }

    var category: SyllogismTypeCategory {
        switch self {
        case .modusPonens, .modusTollens, .affirmConsequent, .denyAntecedent,
             .disjunctiveSyllogism, .disjunctiveFallacy, .constructiveDilemma,
             .biconditional, .biconditionalValid:
            return .propositional
        case .categoricalValid, .categoricalInvalid, .celarent, .darii,
             .ferio, .illicitMajor, .fourTerms:
            return .categorical
        case .quantifierTrap, .universalInstantiation, .existentialFallacy,
             .quantifierNegation, .scopeAmbiguity:
            return .quantifier
        case .chainReasoning, .contraposition, .deMorgan, .absorption:
            return .compound
        case .correlationCausation, .reverseCausation, .baseRateNeglect,
             .gamblerFallacy, .conjunctionFallacy, .slipperySlope:
            return .causalStatistical
        case .falseDilemma, .circularReasoning, .equivocation,
             .hastyGeneralization, .compositionDivision:
            return .argumentStructure
        }
    }

    var displayName: String {
        switch self {
        case .modusPonens:            "肯定前件"
        case .modusTollens:           "否定后件"
        case .affirmConsequent:       "肯定后件"
        case .denyAntecedent:         "否定前件"
        case .disjunctiveSyllogism:   "析取三段论"
        case .disjunctiveFallacy:     "析取谬误"
        case .constructiveDilemma:    "构造性两难"
        case .biconditional:          "双条件推理"
        case .biconditionalValid:     "双条件逆向"
        case .categoricalValid:       "有效三段论"
        case .categoricalInvalid:     "未分配中项"
        case .celarent:               "Celarent 否定"
        case .darii:                  "Darii 特称"
        case .ferio:                  "Ferio 特称否定"
        case .illicitMajor:           "大项不当周延"
        case .fourTerms:              "四项谬误"
        case .quantifierTrap:         "量词偷换"
        case .universalInstantiation: "全称实例化"
        case .existentialFallacy:     "存在泛化谬误"
        case .quantifierNegation:     "量词否定"
        case .scopeAmbiguity:         "量词辖域歧义"
        case .chainReasoning:         "假言连锁"
        case .contraposition:         "逆否命题"
        case .deMorgan:               "德摩根定律"
        case .absorption:             "吸收律"
        case .correlationCausation:   "相关≠因果"
        case .reverseCausation:       "倒果为因"
        case .baseRateNeglect:        "基率忽略"
        case .gamblerFallacy:         "赌徒谬误"
        case .conjunctionFallacy:     "合取谬误"
        case .slipperySlope:          "滑坡谬误"
        case .falseDilemma:           "虚假二分"
        case .circularReasoning:      "循环论证"
        case .equivocation:           "歧义谬误"
        case .hastyGeneralization:    "以偏概全"
        case .compositionDivision:    "合成/分割谬误"
        }
    }

    /// Which lesson group (1-13) this type belongs to
    var lessonGroup: Int {
        switch self {
        case .modusPonens, .affirmConsequent:                                    return 1
        case .categoricalValid, .categoricalInvalid:                             return 2
        case .disjunctiveSyllogism, .disjunctiveFallacy:                         return 3
        case .correlationCausation, .falseDilemma, .hastyGeneralization:          return 4
        case .modusTollens, .denyAntecedent, .contraposition:                    return 5
        case .celarent, .darii, .illicitMajor:                                   return 6
        case .quantifierTrap, .existentialFallacy:                               return 7
        case .chainReasoning, .biconditional, .biconditionalValid:               return 8
        case .reverseCausation, .gamblerFallacy, .slipperySlope:                 return 9
        case .ferio, .constructiveDilemma, .deMorgan:                            return 10
        case .quantifierNegation, .scopeAmbiguity, .fourTerms:                   return 11
        case .baseRateNeglect, .conjunctionFallacy:                              return 12
        case .circularReasoning, .equivocation, .compositionDivision, .absorption: return 13
        case .universalInstantiation:                                            return 7
        }
    }

    var difficultyRange: ClosedRange<Int> {
        switch lessonGroup {
        case 1...4:  return 1...3
        case 5...9:  return 2...3
        case 10...13: return 3...3
        default:      return 1...3
        }
    }

    /// Types commonly confused with this one
    var confusibleWith: [SyllogismType] {
        switch self {
        case .modusPonens:            return [.affirmConsequent]
        case .affirmConsequent:       return [.modusPonens]
        case .modusTollens:           return [.denyAntecedent]
        case .denyAntecedent:         return [.modusTollens]
        case .contraposition:         return [.modusTollens, .affirmConsequent]
        case .disjunctiveSyllogism:   return [.disjunctiveFallacy]
        case .disjunctiveFallacy:     return [.disjunctiveSyllogism]
        case .categoricalValid:       return [.categoricalInvalid]
        case .categoricalInvalid:     return [.categoricalValid]
        case .quantifierTrap:         return [.universalInstantiation]
        case .existentialFallacy:     return [.universalInstantiation]
        case .correlationCausation:   return [.reverseCausation]
        case .reverseCausation:       return [.correlationCausation]
        case .biconditional:          return [.modusPonens]
        case .biconditionalValid:     return [.affirmConsequent]
        default:                      return []
        }
    }

    static func available(for difficulty: Int) -> [SyllogismType] {
        allCases.filter { $0.difficultyRange.contains(difficulty) }
    }

    static func typesInLesson(_ lessonGroup: Int) -> [SyllogismType] {
        allCases.filter { $0.lessonGroup == lessonGroup }
    }
}

// MARK: - Type Statistics (cross-session persistence)

struct SyllogismTypeStats: Codable, Equatable {
    var totalAttempts: Int = 0
    var correctCount: Int = 0

    var accuracy: Double {
        totalAttempts > 0 ? Double(correctCount) / Double(totalAttempts) : 0
    }

    var isWeak: Bool { totalAttempts >= 3 && accuracy < 0.6 }

    mutating func record(correct: Bool) {
        totalAttempts += 1
        if correct { correctCount += 1 }
    }
}

// MARK: - Trial

struct SyllogismTrial: Identifiable {
    let id: String
    let premises: [String]
    let conclusion: String
    let isValid: Bool
    let type: SyllogismType
    let abstractForm: String
    let explanation: String
    let detailedExplanation: String
    let hasUnverifiedPremise: Bool

    init(
        id: String = UUID().uuidString,
        premises: [String],
        conclusion: String,
        isValid: Bool,
        type: SyllogismType,
        abstractForm: String,
        explanation: String,
        detailedExplanation: String = "",
        hasUnverifiedPremise: Bool = false
    ) {
        self.id = id
        self.premises = premises
        self.conclusion = conclusion
        self.isValid = isValid
        self.type = type
        self.abstractForm = abstractForm
        self.explanation = explanation
        self.detailedExplanation = detailedExplanation
        self.hasUnverifiedPremise = hasUnverifiedPremise
    }
}

struct SyllogismTrialResult {
    let trialIndex: Int
    let trial: SyllogismTrial
    let userAnswer: Bool         // true = 用户判断"有效"
    let isCorrect: Bool
    let reactionTime: TimeInterval?
    let usedHint: Bool
}

// MARK: - Metrics

struct SyllogismMetrics: Codable, Equatable {
    var difficulty: Int
    var totalTrials: Int
    var correctCount: Int
    var accuracy: Double
    var medianRT: TimeInterval
    var validAccuracy: Double        // 对有效推理的正确率
    var invalidAccuracy: Double      // 对无效推理的正确率
    var beliefBiasErrorRate: Double   // 信念偏差错误率
    var hintUsageCount: Int
    var dPrime: Double

    static func compute(
        from results: [SyllogismTrialResult],
        difficulty: Int
    ) -> SyllogismMetrics {
        let total = results.count
        let correct = results.filter(\.isCorrect).count
        let accuracy = total > 0 ? Double(correct) / Double(total) : 0

        let validTrials = results.filter { $0.trial.isValid }
        let invalidTrials = results.filter { !$0.trial.isValid }
        let validCorrect = validTrials.filter(\.isCorrect).count
        let invalidCorrect = invalidTrials.filter(\.isCorrect).count
        let validAcc = validTrials.isEmpty ? 0 : Double(validCorrect) / Double(validTrials.count)
        let invalidAcc = invalidTrials.isEmpty ? 0 : Double(invalidCorrect) / Double(invalidTrials.count)

        // d' calculation: hit = correctly identify valid, false alarm = incorrectly call invalid "valid"
        let hitRate = clamped(validAcc, min: 0.01, max: 0.99)
        let falseAlarmRate = clamped(invalidTrials.isEmpty ? 0.5 : 1.0 - invalidAcc, min: 0.01, max: 0.99)
        let dPrime = zScore(hitRate) - zScore(falseAlarmRate)

        let rts = results.compactMap(\.reactionTime).sorted()
        let medianRT = rts.isEmpty ? 0 : rts[rts.count / 2]

        let hintCount = results.filter(\.usedHint).count

        // Belief bias: not directly trackable without marking trials, default 0
        let beliefBiasErrorRate: Double = 0

        return SyllogismMetrics(
            difficulty: difficulty,
            totalTrials: total,
            correctCount: correct,
            accuracy: accuracy,
            medianRT: medianRT,
            validAccuracy: validAcc,
            invalidAccuracy: invalidAcc,
            beliefBiasErrorRate: beliefBiasErrorRate,
            hintUsageCount: hintCount,
            dPrime: dPrime
        )
    }

    private static func clamped(_ value: Double, min: Double, max: Double) -> Double {
        Swift.min(Swift.max(value, min), max)
    }

    private static func zScore(_ p: Double) -> Double {
        // Rational approximation of inverse normal CDF (Beasley-Springer-Moro)
        let a: [Double] = [-3.969683028665376e1, 2.209460984245205e2, -2.759285104469687e2,
                           1.383577518672690e2, -3.066479806614716e1, 2.506628277459239e0]
        let b: [Double] = [-5.447609879822406e1, 1.615858368580409e2, -1.556989798598866e2,
                           6.680131188771972e1, -1.328068155288572e1]
        let c: [Double] = [-7.784894002430293e-3, -3.223964580411365e-1, -2.400758277161838e0,
                           -2.549732539343734e0, 4.374664141464968e0, 2.938163982698783e0]
        let d: [Double] = [7.784695709041462e-3, 3.224671290700398e-1, 2.445134137142996e0, 3.754408661907416e0]

        let pLow = 0.02425
        let pHigh = 1.0 - pLow
        var q: Double
        var r: Double

        if p < pLow {
            q = sqrt(-2.0 * log(p))
            return (((((c[0]*q+c[1])*q+c[2])*q+c[3])*q+c[4])*q+c[5]) /
                   ((((d[0]*q+d[1])*q+d[2])*q+d[3])*q+1.0)
        } else if p <= pHigh {
            q = p - 0.5
            r = q * q
            return (((((a[0]*r+a[1])*r+a[2])*r+a[3])*r+a[4])*r+a[5])*q /
                   (((((b[0]*r+b[1])*r+b[2])*r+b[3])*r+b[4])*r+1.0)
        } else {
            q = sqrt(-2.0 * log(1.0 - p))
            return -(((((c[0]*q+c[1])*q+c[2])*q+c[3])*q+c[4])*q+c[5]) /
                    ((((d[0]*q+d[1])*q+d[2])*q+d[3])*q+1.0)
        }
    }
}
