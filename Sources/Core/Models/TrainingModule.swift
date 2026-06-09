import Foundation

enum TrainingModule: String, Codable, CaseIterable, Identifiable, Hashable {
    case mainIdea
    case evidenceMap
    case delayedRecall
    case syllogism
    case logicArgument
    case logicReasoning
    case schulte
    case nBack
    case digitSpan
    case changeDetection
    case corsiBlock
    case civilExam
    case devilTraining

    var id: String { rawValue }

    static let allCases: [TrainingModule] = [
        .mainIdea,
        .evidenceMap,
        .delayedRecall,
        .syllogism,
        .logicArgument,
        .logicReasoning,
        .schulte,
        .nBack,
        .digitSpan,
        .changeDetection,
        .corsiBlock,
        .civilExam,
        .devilTraining,
    ]

    static let coreCases: [TrainingModule] = [
        .mainIdea,
        .evidenceMap,
        .delayedRecall,
        .syllogism,
        .logicArgument,
        .schulte,
        .nBack,
    ]

    static let supportCases: [TrainingModule] = [
        .digitSpan,
        .changeDetection,
        .corsiBlock,
    ]

    static let legacyCases: [TrainingModule] = supportCases

    enum Dimension: String, CaseIterable, Identifiable {
        case reading
        case logicalReasoning
        case memory
        case visualAttention

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .reading:          "阅读训练"
            case .logicalReasoning: "逻辑推理"
            case .memory:           "记忆力"
            case .visualAttention:  "视觉注意"
            }
        }

        var modules: [TrainingModule] {
            TrainingModule.allCases.filter { $0.dimension == self }
        }
    }

    var dimension: Dimension {
        switch self {
        case .mainIdea, .evidenceMap, .delayedRecall:            .reading
        case .syllogism, .logicArgument, .logicReasoning, .civilExam: .logicalReasoning
        case .digitSpan, .nBack, .changeDetection, .corsiBlock, .devilTraining: .memory
        case .schulte:                                          .visualAttention
        }
    }

    var displayName: String {
        switch self {
        case .mainIdea:       "主旨提取"
        case .evidenceMap:    "结构证据"
        case .delayedRecall:  "延迟回忆"
        case .syllogism:       "逻辑快判"
        case .logicArgument:   "论证分析"
        case .logicReasoning:  "逻辑推理"
        case .schulte:         "舒尔特方格"
        case .nBack:           "N-Back 记忆"
        case .digitSpan:       "数字广度"
        case .changeDetection: "变更检测"
        case .corsiBlock:      "空间广度"
        case .civilExam:       "考公行测"
        case .devilTraining:   "魔鬼锻炼"
        }
    }

    var shortName: String {
        switch self {
        case .mainIdea:       "主旨"
        case .evidenceMap:    "证据"
        case .delayedRecall:  "回忆"
        case .syllogism:       "逻辑快判"
        case .logicArgument:   "论证分析"
        case .logicReasoning:  "逻辑推理"
        case .schulte:         "舒尔特"
        case .nBack:           "N-Back"
        case .digitSpan:       "数字广度"
        case .changeDetection: "变更检测"
        case .corsiBlock:      "空间广度"
        case .civilExam:       "考公"
        case .devilTraining:   "魔鬼"
        }
    }

    var systemImage: String {
        switch self {
        case .mainIdea:       "text.alignleft"
        case .evidenceMap:    "list.bullet.clipboard"
        case .delayedRecall:  "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .syllogism:       "bolt.trianglebadge.exclamationmark"
        case .logicArgument:   "puzzlepiece.extension"
        case .logicReasoning:  "brain.head.profile"
        case .schulte:         "square.grid.3x3.fill"
        case .nBack:           "number.square.fill"
        case .digitSpan:       "brain"
        case .changeDetection: "eye.fill"
        case .corsiBlock:      "square.grid.3x3.topleft.filled"
        case .civilExam:       "building.columns.fill"
        case .devilTraining:   "flame.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .mainIdea:       "快速抓取说明文主干"
        case .evidenceMap:    "定位结论、证据与限制"
        case .delayedRecall:  "读后保持与结构化提取"
        case .syllogism:       "形式逻辑推理速度与准确性"
        case .logicArgument:   "论证结构·谬误识别·论证评估"
        case .logicReasoning:  "演绎推理与逻辑谜题"
        case .schulte:         "视觉注意力与周边视觉"
        case .nBack:           "工作记忆更新能力"
        case .digitSpan:       "短时记忆与工作记忆"
        case .changeDetection: "视觉工作记忆"
        case .corsiBlock:      "视觉空间工作记忆"
        case .civilExam:       "行测题库：判断·言语·数量·资料"
        case .devilTraining:   "限时高压·连击计分·自适应加难"
        }
    }

    var skillCategory: SkillCategory {
        switch self {
        case .mainIdea, .evidenceMap, .delayedRecall:
            .readingComprehension
        case .syllogism, .logicArgument, .logicReasoning, .civilExam:
            .logicalReasoning
        case .digitSpan, .nBack, .changeDetection, .corsiBlock, .devilTraining:
            .memory
        case .schulte:
            .visualAttentionSearch
        }
    }

    var adaptiveLevelRange: ClosedRange<Int> {
        switch self {
        case .mainIdea, .evidenceMap, .delayedRecall, .syllogism, .logicArgument, .logicReasoning, .civilExam:
            1...3
        case .schulte:
            1...7
        default:
            1...6
        }
    }

    var defaultAdaptiveLevel: Int {
        switch self {
        case .mainIdea, .evidenceMap, .delayedRecall, .syllogism, .logicArgument, .logicReasoning, .civilExam:
            1
        case .schulte:
            2
        case .digitSpan, .corsiBlock, .nBack, .changeDetection, .devilTraining:
            3
        }
    }

    func normalizedLevel(_ level: Int) -> Double {
        let range = adaptiveLevelRange
        let clamped = min(max(level, range.lowerBound), range.upperBound)
        let span = max(1, range.upperBound - range.lowerBound)
        return Double(clamped - range.lowerBound) / Double(span)
    }

    /// Whether this module can be launched directly without user-selected materials.
    /// Reading and logic modules require passage/trial selection, so they are not quick-startable.
    var isQuickStartable: Bool {
        switch self {
        case .mainIdea, .evidenceMap, .delayedRecall, .syllogism, .logicArgument, .civilExam, .devilTraining:
            false
        default:
            true
        }
    }
}
