import SwiftUI

enum AppRoute: String, CaseIterable, Identifiable, Hashable {
    case home
    case mainIdea
    case evidenceMap
    case delayedRecall
    case syllogism
    case logicArgument
    case schulte
    case visualSearch
    case flanker
    case goNoGo
    case stopSignal
    case nBack
    case digitSpan
    case corsiBlock
    case changeDetection
    case choiceRT
    case materialsWorkbench
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "控制台"
        case .mainIdea: return "主旨提取"
        case .evidenceMap: return "证据结构"
        case .delayedRecall: return "延迟回忆"
        case .syllogism: return "逻辑快判"
        case .logicArgument: return "论证分析"
        case .schulte: return "舒尔特方格"
        case .visualSearch: return "视觉搜索"
        case .flanker: return "Flanker"
        case .goNoGo: return "Go/No-Go"
        case .stopSignal: return "Stop-Signal"
        case .nBack: return "N-Back"
        case .digitSpan: return "数字广度"
        case .corsiBlock: return "Corsi 方块"
        case .changeDetection: return "变化检测"
        case .choiceRT: return "选择反应"
        case .materialsWorkbench: return "素材"
        case .history: return "历史"
        case .settings: return "设置"
        }
    }

    var navigationTitle: String {
        switch presentationProfile.cluster {
        case .controlCenter:
            return "控制台"
        case .trainingLibrary:
            return "训练库"
        case .analysis:
            return "分析"
        case .materials:
            return "素材"
        case .settings:
            return "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "rectangle.stack.fill"
        case .mainIdea: return "text.alignleft"
        case .evidenceMap: return "list.bullet.clipboard"
        case .delayedRecall: return "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .syllogism: return "bolt.trianglebadge.exclamationmark"
        case .logicArgument: return "puzzlepiece.extension"
        case .schulte: return "square.grid.3x3.fill"
        case .visualSearch: return "magnifyingglass"
        case .flanker: return "arrow.left.arrow.right"
        case .goNoGo: return "hand.raised.fill"
        case .stopSignal: return "stop.circle.fill"
        case .nBack: return "number.square.fill"
        case .digitSpan: return "textformat.123"
        case .corsiBlock: return "square.on.square"
        case .changeDetection: return "eye.trianglebadge.exclamationmark"
        case .choiceRT: return "bolt.fill"
        case .materialsWorkbench: return "tray.full.fill"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "slider.horizontal.3"
        }
    }

    var trainingModule: TrainingModule? {
        switch self {
        case .mainIdea: return .mainIdea
        case .evidenceMap: return .evidenceMap
        case .delayedRecall: return .delayedRecall
        case .syllogism: return .syllogism
        case .logicArgument: return .logicArgument
        case .schulte: return .schulte
        case .visualSearch: return .visualSearch
        case .flanker: return .flanker
        case .goNoGo: return .goNoGo
        case .stopSignal: return .stopSignal
        case .nBack: return .nBack
        case .digitSpan: return .digitSpan
        case .corsiBlock: return .corsiBlock
        case .changeDetection: return .changeDetection
        case .choiceRT: return .choiceRT
        default: return nil
        }
    }

    var isModule: Bool { trainingModule != nil }

    static let readingModules: [AppRoute] = [.mainIdea, .evidenceMap, .delayedRecall]
    static let logicModules: [AppRoute] = [.syllogism, .logicArgument]
    static let attentionModules: [AppRoute] = [.schulte, .visualSearch]
    static let inhibitionModules: [AppRoute] = [.flanker, .goNoGo, .stopSignal]
    static let memoryModules: [AppRoute] = [.nBack, .digitSpan, .corsiBlock, .changeDetection]
    static let speedModules: [AppRoute] = [.choiceRT]
    static let tools: [AppRoute] = [.home, .materialsWorkbench, .history, .settings]

    static let supportAttention: [AppRoute] = attentionModules
    static let supportInhibition: [AppRoute] = inhibitionModules
    static let supportMemory: [AppRoute] = memoryModules + speedModules
    static let supportModules: [AppRoute] = attentionModules + inhibitionModules + memoryModules + speedModules

    var presentationProfile: ModulePresentationProfile {
        switch self {
        case .home:
            return ModulePresentationProfile(
                accent: BDColor.primaryBlue,
                shellMode: .workspace,
                tone: .analytics,
                cluster: .controlCenter,
                subtitle: "今日训练、短板提醒与近期表现",
                shortDescription: "查看推荐训练、关键指标与近期记录"
            )
        case .mainIdea:
            return ModulePresentationProfile(
                accent: BDColor.gold,
                shellMode: .training,
                tone: .reading,
                cluster: .trainingLibrary,
                subtitle: "主动概括阅读材料的中心命题",
                shortDescription: "抓取主题对象、关系与全文主旨"
            )
        case .evidenceMap:
            return ModulePresentationProfile(
                accent: BDColor.teal,
                shellMode: .training,
                tone: .reading,
                cluster: .trainingLibrary,
                subtitle: "拆出结论、证据与条件限制",
                shortDescription: "定位论证结构与支撑证据"
            )
        case .delayedRecall:
            return ModulePresentationProfile(
                accent: BDColor.green,
                shellMode: .training,
                tone: .reading,
                cluster: .trainingLibrary,
                subtitle: "延时回忆关键信息与主干结构",
                shortDescription: "检验阅读保持与信息提取能力"
            )
        case .syllogism:
            return ModulePresentationProfile(
                accent: BDColor.syllogismAccent,
                shellMode: .training,
                tone: .logic,
                cluster: .trainingLibrary,
                subtitle: "快速判断三段论是否成立",
                shortDescription: "形式逻辑的速度与准确性"
            )
        case .logicArgument:
            return ModulePresentationProfile(
                accent: BDColor.logicArgumentAccent,
                shellMode: .training,
                tone: .logic,
                cluster: .trainingLibrary,
                subtitle: "拆解论证结构、谬误与评估",
                shortDescription: "批判性思维与论证分析训练"
            )
        case .schulte:
            return ModulePresentationProfile(
                accent: BDColor.primaryBlue,
                shellMode: .training,
                tone: .attention,
                cluster: .trainingLibrary,
                subtitle: "连续扫描、目标定位与视野控制",
                shortDescription: "视觉扫描与持续注意"
            )
        case .visualSearch:
            return ModulePresentationProfile(
                accent: BDColor.visualSearchAccent,
                shellMode: .training,
                tone: .attention,
                cluster: .trainingLibrary,
                subtitle: "从干扰中快速定位目标",
                shortDescription: "选择性注意与搜索效率"
            )
        case .flanker:
            return ModulePresentationProfile(
                accent: BDColor.flankerAccent,
                shellMode: .training,
                tone: .inhibition,
                cluster: .trainingLibrary,
                subtitle: "在冲突刺激下稳定做出选择",
                shortDescription: "冲突抑制与选择性注意"
            )
        case .goNoGo:
            return ModulePresentationProfile(
                accent: BDColor.goNoGoAccent,
                shellMode: .training,
                tone: .inhibition,
                cluster: .trainingLibrary,
                subtitle: "在动机诱发下抑制错误反应",
                shortDescription: "动作抑制与冲动控制"
            )
        case .stopSignal:
            return ModulePresentationProfile(
                accent: BDColor.stopSignalAccent,
                shellMode: .training,
                tone: .inhibition,
                cluster: .trainingLibrary,
                subtitle: "启动后快速取消反应",
                shortDescription: "停止信号下的抑制控制"
            )
        case .nBack:
            return ModulePresentationProfile(
                accent: BDColor.nBackAccent,
                shellMode: .training,
                tone: .memory,
                cluster: .trainingLibrary,
                subtitle: "动态更新工作记忆中的目标项目",
                shortDescription: "工作记忆负荷与更新能力"
            )
        case .digitSpan:
            return ModulePresentationProfile(
                accent: BDColor.digitSpanAccent,
                shellMode: .training,
                tone: .memory,
                cluster: .trainingLibrary,
                subtitle: "保持与操作言语短时记忆",
                shortDescription: "数字保持与工作记忆容量"
            )
        case .corsiBlock:
            return ModulePresentationProfile(
                accent: BDColor.corsiBlockAccent,
                shellMode: .training,
                tone: .memory,
                cluster: .trainingLibrary,
                subtitle: "追踪空间序列并重复回放",
                shortDescription: "视空间工作记忆测量"
            )
        case .changeDetection:
            return ModulePresentationProfile(
                accent: BDColor.changeDetectionAccent,
                shellMode: .training,
                tone: .memory,
                cluster: .trainingLibrary,
                subtitle: "在短时保持中检测视觉变化",
                shortDescription: "视觉工作记忆容量评估"
            )
        case .choiceRT:
            return ModulePresentationProfile(
                accent: BDColor.choiceRTAccent,
                shellMode: .training,
                tone: .speed,
                cluster: .trainingLibrary,
                subtitle: "感知到决策再到动作输出的反应速度",
                shortDescription: "信息处理速度与决策效率"
            )
        case .materialsWorkbench:
            return ModulePresentationProfile(
                accent: BDColor.warm,
                shellMode: .workspace,
                tone: .analytics,
                cluster: .materials,
                subtitle: "抓取、清洗、审核并管理阅读素材",
                shortDescription: "自动抓取开放来源并人工审核入库"
            )
        case .history:
            return ModulePresentationProfile(
                accent: BDColor.teal,
                shellMode: .workspace,
                tone: .analytics,
                cluster: .analysis,
                subtitle: "按模块回看训练结果与表现记录",
                shortDescription: "按模块过滤并查看训练历史"
            )
        case .settings:
            return ModulePresentationProfile(
                accent: BDColor.textSecondary,
                shellMode: .workspace,
                tone: .neutral,
                cluster: .settings,
                subtitle: "调整训练参数、AI 配置与本地数据设置",
                shortDescription: "配置训练参数和本地工作环境"
            )
        }
    }
}
