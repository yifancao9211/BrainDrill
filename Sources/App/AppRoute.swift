import SwiftUI

enum AppRoute: String, CaseIterable, Identifiable, Hashable {
    case home
    case mainIdea
    case evidenceMap
    case delayedRecall
    case schulte
    case visualSearch
    case nBack
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:          "首页"
        case .mainIdea:      "主旨提取"
        case .evidenceMap:   "结构证据"
        case .delayedRecall: "延迟回忆"
        case .schulte:       "舒尔特方格"
        case .visualSearch:  "视觉搜索"
        case .nBack:         "N-Back 记忆"
        case .history:       "历史记录"
        case .settings:      "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .home:          "house"
        case .mainIdea:      "text.alignleft"
        case .evidenceMap:   "list.bullet.clipboard"
        case .delayedRecall: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .schulte:       "square.grid.3x3.fill"
        case .visualSearch:  "magnifyingglass"
        case .nBack:         "number.square.fill"
        case .history:       "clock.arrow.circlepath"
        case .settings:      "slider.horizontal.3"
        }
    }

    var trainingModule: TrainingModule? {
        switch self {
        case .mainIdea:      .mainIdea
        case .evidenceMap:   .evidenceMap
        case .delayedRecall: .delayedRecall
        case .schulte:       .schulte
        case .visualSearch:  .visualSearch
        case .nBack:         .nBack
        default:             nil
        }
    }

    var isModule: Bool { trainingModule != nil }

    static let readingModules: [AppRoute] = [.mainIdea, .evidenceMap, .delayedRecall]
    static let supportModules: [AppRoute] = [.schulte, .visualSearch, .nBack]
    static let tools: [AppRoute] = [.home, .history, .settings]

    var presentationProfile: ModulePresentationProfile {
        switch self {
        case .home:
            ModulePresentationProfile(accent: BDColor.gold, shellMode: .workbench, tone: .analytics, subtitle: "阅读主线、建议与精简统计")
        case .mainIdea:
            ModulePresentationProfile(accent: BDColor.gold, shellMode: .trainingFocus, tone: .reading, subtitle: "快速抓主旨与主干")
        case .evidenceMap:
            ModulePresentationProfile(accent: BDColor.teal, shellMode: .trainingFocus, tone: .reading, subtitle: "定位结论、证据与限制")
        case .delayedRecall:
            ModulePresentationProfile(accent: BDColor.green, shellMode: .trainingFocus, tone: .reading, subtitle: "延迟提取核心信息")
        case .schulte:
            ModulePresentationProfile(accent: BDColor.primaryBlue, shellMode: .trainingFocus, tone: .visual, subtitle: "视觉扫描与持续注意")
        case .visualSearch:
            ModulePresentationProfile(accent: BDColor.visualSearchAccent, shellMode: .trainingFocus, tone: .visual, subtitle: "目标搜索与干扰抑制")
        case .nBack:
            ModulePresentationProfile(accent: BDColor.nBackAccent, shellMode: .trainingFocus, tone: .memory, subtitle: "动态工作记忆负荷")
        case .history:
            ModulePresentationProfile(accent: BDColor.warm, shellMode: .workbench, tone: .analytics, subtitle: "查看有效训练记录")
        case .settings:
            ModulePresentationProfile(accent: BDColor.textSecondary, shellMode: .workbench, tone: .neutral, subtitle: "基础参数与本地数据")
        }
    }
}
