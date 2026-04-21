import Foundation

enum TrainingModule: String, Codable, CaseIterable, Identifiable, Hashable {
    case mainIdea
    case evidenceMap
    case delayedRecall
    case syllogism
    case logicArgument
    case schulte
    case nBack
    case visualSearch
    case flanker
    case goNoGo
    case digitSpan
    case choiceRT
    case changeDetection
    case corsiBlock
    case stopSignal

    var id: String { rawValue }

    static let allCases: [TrainingModule] = [
        .mainIdea,
        .evidenceMap,
        .delayedRecall,
        .syllogism,
        .logicArgument,
        .schulte,
        .visualSearch,
        .nBack,
    ]

    static let legacyCases: [TrainingModule] = [
        .flanker,
        .goNoGo,
        .digitSpan,
        .choiceRT,
        .changeDetection,
        .corsiBlock,
        .stopSignal,
    ]

    enum Dimension: String, CaseIterable, Identifiable {
        case reading
        case logicalReasoning
        case memory
        case reaction
        case visualAttention

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .reading:          "阅读训练"
            case .logicalReasoning: "逻辑推理"
            case .memory:           "记忆力"
            case .reaction:         "反应力"
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
        case .syllogism, .logicArgument:                        .logicalReasoning
        case .digitSpan, .nBack, .changeDetection, .corsiBlock: .memory
        case .choiceRT, .goNoGo, .flanker, .stopSignal:         .reaction
        case .schulte, .visualSearch:                           .visualAttention
        }
    }

    var displayName: String {
        switch self {
        case .mainIdea:       "主旨提取"
        case .evidenceMap:    "结构证据"
        case .delayedRecall:  "延迟回忆"
        case .syllogism:       "逻辑快判"
        case .logicArgument:   "论证分析"
        case .schulte:         "舒尔特方格"
        case .flanker:         "Flanker 反应力"
        case .goNoGo:          "Go/No-Go 抑制力"
        case .nBack:           "N-Back 记忆"
        case .digitSpan:       "数字广度"
        case .choiceRT:        "选择反应时"
        case .changeDetection: "变更检测"
        case .visualSearch:    "视觉搜索"
        case .corsiBlock:      "空间广度"
        case .stopSignal:      "Stop-Signal"
        }
    }

    var shortName: String {
        switch self {
        case .mainIdea:       "主旨"
        case .evidenceMap:    "证据"
        case .delayedRecall:  "回忆"
        case .syllogism:       "逻辑快判"
        case .logicArgument:   "论证分析"
        case .schulte:         "舒尔特"
        case .flanker:         "Flanker"
        case .goNoGo:          "Go/No-Go"
        case .nBack:           "N-Back"
        case .digitSpan:       "数字广度"
        case .choiceRT:        "选择RT"
        case .changeDetection: "变更检测"
        case .visualSearch:    "视觉搜索"
        case .corsiBlock:      "空间广度"
        case .stopSignal:      "Stop-Signal"
        }
    }

    var systemImage: String {
        switch self {
        case .mainIdea:       "text.alignleft"
        case .evidenceMap:    "list.bullet.clipboard"
        case .delayedRecall:  "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .syllogism:       "bolt.trianglebadge.exclamationmark"
        case .logicArgument:   "puzzlepiece.extension"
        case .schulte:         "square.grid.3x3.fill"
        case .flanker:         "arrow.left.arrow.right"
        case .goNoGo:          "hand.raised.fill"
        case .nBack:           "number.square.fill"
        case .digitSpan:       "brain"
        case .choiceRT:        "bolt.fill"
        case .changeDetection: "eye.fill"
        case .visualSearch:    "magnifyingglass"
        case .corsiBlock:      "square.grid.3x3.topleft.filled"
        case .stopSignal:      "stop.circle.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .mainIdea:       "快速抓取说明文主干"
        case .evidenceMap:    "定位结论、证据与限制"
        case .delayedRecall:  "读后保持与结构化提取"
        case .syllogism:       "形式逻辑推理速度与准确性"
        case .logicArgument:   "论证结构·谬误识别·论证评估"
        case .schulte:         "视觉注意力与周边视觉"
        case .flanker:         "选择性注意力与抑制控制"
        case .goNoGo:          "反应抑制与冲动控制"
        case .nBack:           "工作记忆更新能力"
        case .digitSpan:       "短时记忆与工作记忆"
        case .choiceRT:        "感知-决策-反应速度"
        case .changeDetection: "视觉工作记忆"
        case .visualSearch:    "选择性注意与搜索效率"
        case .corsiBlock:      "视觉空间工作记忆"
        case .stopSignal:      "动作抑制与停止控制"
        }
    }

    var skillCategory: SkillCategory {
        switch self {
        case .mainIdea, .evidenceMap, .delayedRecall:
            .readingComprehension
        case .syllogism, .logicArgument:
            .logicalReasoning
        case .digitSpan, .nBack, .changeDetection, .corsiBlock:
            .memory
        case .choiceRT, .flanker:
            .reactionSpeed
        case .goNoGo, .stopSignal:
            .inhibitionControl
        case .schulte, .visualSearch:
            .visualAttentionSearch
        }
    }

    var adaptiveLevelRange: ClosedRange<Int> {
        switch self {
        case .mainIdea, .evidenceMap, .delayedRecall, .syllogism, .logicArgument:
            1...3
        case .schulte:
            1...7
        default:
            1...6
        }
    }

    var defaultAdaptiveLevel: Int {
        switch self {
        case .mainIdea, .evidenceMap, .delayedRecall, .syllogism, .logicArgument:
            1
        case .schulte:
            2
        case .digitSpan, .corsiBlock, .nBack, .changeDetection:
            3
        default:
            3
        }
    }

    func normalizedLevel(_ level: Int) -> Double {
        let range = adaptiveLevelRange
        let clamped = min(max(level, range.lowerBound), range.upperBound)
        let span = max(1, range.upperBound - range.lowerBound)
        return Double(clamped - range.lowerBound) / Double(span)
    }
}
