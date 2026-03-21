import Foundation

enum TrainingModule: String, Codable, CaseIterable, Identifiable, Hashable {
    case schulte
    case flanker
    case goNoGo
    case nBack
    case digitSpan
    case choiceRT
    case changeDetection
    case visualSearch

    var id: String { rawValue }

    enum Dimension: String, CaseIterable, Identifiable {
        case memory
        case reaction
        case visualAttention

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .memory:          "记忆力"
            case .reaction:        "反应力"
            case .visualAttention: "视觉注意"
            }
        }

        var modules: [TrainingModule] {
            TrainingModule.allCases.filter { $0.dimension == self }
        }
    }

    var dimension: Dimension {
        switch self {
        case .digitSpan, .nBack, .changeDetection: .memory
        case .choiceRT, .goNoGo, .flanker:         .reaction
        case .schulte, .visualSearch:               .visualAttention
        }
    }

    var displayName: String {
        switch self {
        case .schulte:         "舒尔特方格"
        case .flanker:         "Flanker 反应力"
        case .goNoGo:          "Go/No-Go 抑制力"
        case .nBack:           "N-Back 记忆"
        case .digitSpan:       "数字广度"
        case .choiceRT:        "选择反应时"
        case .changeDetection: "变更检测"
        case .visualSearch:    "视觉搜索"
        }
    }

    var shortName: String {
        switch self {
        case .schulte:         "舒尔特"
        case .flanker:         "Flanker"
        case .goNoGo:          "Go/No-Go"
        case .nBack:           "N-Back"
        case .digitSpan:       "数字广度"
        case .choiceRT:        "选择RT"
        case .changeDetection: "变更检测"
        case .visualSearch:    "视觉搜索"
        }
    }

    var systemImage: String {
        switch self {
        case .schulte:         "square.grid.3x3.fill"
        case .flanker:         "arrow.left.arrow.right"
        case .goNoGo:          "hand.raised.fill"
        case .nBack:           "number.square.fill"
        case .digitSpan:       "brain"
        case .choiceRT:        "bolt.fill"
        case .changeDetection: "eye.fill"
        case .visualSearch:    "magnifyingglass"
        }
    }

    var subtitle: String {
        switch self {
        case .schulte:         "视觉注意力与周边视觉"
        case .flanker:         "选择性注意力与抑制控制"
        case .goNoGo:          "反应抑制与冲动控制"
        case .nBack:           "工作记忆更新能力"
        case .digitSpan:       "短时记忆与工作记忆"
        case .choiceRT:        "感知-决策-反应速度"
        case .changeDetection: "视觉工作记忆"
        case .visualSearch:    "选择性注意与搜索效率"
        }
    }
}
