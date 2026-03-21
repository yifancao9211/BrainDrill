import Foundation

enum AppRoute: String, CaseIterable, Identifiable, Hashable {
    case dailyPlan
    case schulte
    case flanker
    case goNoGo
    case nBack
    case digitSpan
    case choiceRT
    case changeDetection
    case visualSearch
    case corsiBlock
    case stopSignal
    case history
    case statistics
    case aiAnalyst
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dailyPlan:       "今日训练"
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
        case .history:         "历史记录"
        case .statistics:      "统计面板"
        case .aiAnalyst:       "AI 分析"
        case .settings:        "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .dailyPlan:       "calendar.badge.clock"
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
        case .history:         "clock.arrow.circlepath"
        case .statistics:      "chart.bar.xaxis"
        case .aiAnalyst:       "sparkles"
        case .settings:        "slider.horizontal.3"
        }
    }

    var trainingModule: TrainingModule? {
        switch self {
        case .schulte:         .schulte
        case .flanker:         .flanker
        case .goNoGo:          .goNoGo
        case .nBack:           .nBack
        case .digitSpan:       .digitSpan
        case .choiceRT:        .choiceRT
        case .changeDetection: .changeDetection
        case .visualSearch:    .visualSearch
        case .corsiBlock:      .corsiBlock
        case .stopSignal:      .stopSignal
        default:               nil
        }
    }

    var isModule: Bool { trainingModule != nil }

    static var memoryModules: [AppRoute] { [.digitSpan, .corsiBlock, .nBack, .changeDetection] }
    static var reactionModules: [AppRoute] { [.choiceRT, .goNoGo, .flanker, .stopSignal] }
    static var visualModules: [AppRoute] { [.schulte, .visualSearch] }
    static var tools: [AppRoute] { [.dailyPlan, .history, .statistics, .aiAnalyst, .settings] }
}
