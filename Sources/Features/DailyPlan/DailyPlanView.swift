import Charts
import SwiftUI

struct DailyPlanView: View {
    @Environment(AppModel.self) private var appModel

    private var recommendedRoutes: [AppRoute] {
        TrainingScheduler.recommend(
            sessions: appModel.sessions.filter { TrainingModule.allCases.contains($0.module) },
            allModules: TrainingModule.allCases,
            maxCount: 4
        ).compactMap { recommendation in
            route(for: recommendation.module)
        }
    }

    private var weakestCategories: [CategorySkillScore] {
        appModel.skillProfile.categoryScores
            .filter { $0.moduleCount > 0 }
            .sorted { $0.score < $1.score }
            .prefix(3)
            .map { $0 }
    }

    private var recentSessions: [SessionResult] {
        Array(appModel.sessions.filter { TrainingModule.allCases.contains($0.module) }.prefix(4))
    }

    var body: some View {
        BDWorkbenchPage(
            title: "控制台",
            subtitle: "从今日推荐开始训练，持续查看短板、节奏与最近表现。",
            maxContentWidth: BDMetrics.contentMaxAnalysisWidth
        ) {
            SurfaceCard(
                title: "今日状态",
                subtitle: "先稳住连续训练，再针对当前短板做 1 到 2 个模块。",
                accent: BDColor.primaryBlue
            ) {
                HStack(spacing: 14) {
                    BDStatCard(label: "连续训练", value: appModel.streakTracker.streakLabel, note: "最长 \(appModel.streakTracker.longestStreak) 天", accent: BDColor.warm, icon: "flame.fill")
                    BDStatCard(label: "累计训练", value: "\(appModel.statistics.totalSessions)", note: "阅读 \(appModel.statistics.readingSessionCount) · 支撑 \(appModel.statistics.supportSessionCount)", accent: BDColor.primaryBlue, icon: "chart.bar.fill")
                    BDStatCard(label: "已解锁成就", value: "\(appModel.achievementTracker.unlockedCount)", note: "总数 \(appModel.achievementTracker.achievements.count)", accent: BDColor.green, icon: "rosette")
                    BDStatCard(label: "综合画像", value: "\(Int(appModel.skillProfile.overallInternalScore))", note: "内部评分", accent: BDColor.teal, icon: "brain.head.profile")
                }
            }

            HStack(alignment: .top, spacing: 20) {
                SurfaceCard(title: "今日推荐流", subtitle: "从系统建议的模块开始，不必自己挑。", accent: BDColor.teal) {
                    VStack(spacing: 12) {
                        if recommendedRoutes.isEmpty {
                            BDInsightCard(title: "还没有训练记录", bodyText: "先从训练库任意开始一个模块，系统才会根据表现推荐下一步。", accent: BDColor.primaryBlue)
                        } else {
                            ForEach(Array(recommendedRoutes.enumerated()), id: \.offset) { index, route in
                                BDInteractiveRow(accent: route.presentationProfile.accent, action: {
                                    appModel.selectedRoute = route
                                }) {
                                    HStack(spacing: 14) {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(route.presentationProfile.accent.opacity(0.14))
                                            .frame(width: 42, height: 42)
                                            .overlay {
                                                Image(systemName: route.systemImage)
                                                    .foregroundStyle(route.presentationProfile.accent)
                                            }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("\(index + 1). \(route.title)")
                                                .font(.system(.headline, weight: .semibold))
                                                .foregroundStyle(BDColor.textPrimary)
                                            Text(route.presentationProfile.shortDescription)
                                                .font(.system(.caption))
                                                .foregroundStyle(BDColor.textSecondary)
                                        }

                                    }
                                } trailing: {
                                    Text(scheduleLabel(for: route))
                                        .font(.system(.caption, weight: .semibold))
                                        .foregroundStyle(route.presentationProfile.accent)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                SurfaceCard(title: "短板提醒", subtitle: "从当前得分较低的能力维度补齐训练。", accent: BDColor.gold) {
                    VStack(spacing: 12) {
                        ForEach(weakestCategories) { item in
                            BDInsightCard(
                                title: item.category.displayName,
                                bodyText: "当前内部得分 \(Int(item.score))，建议优先训练这一维度下的模块，先把稳定性拉起来。",
                                accent: accent(for: item.category)
                            )
                        }
                    }
                }
                .frame(width: 320)
            }

            HStack(alignment: .top, spacing: 20) {
                SurfaceCard(title: "最近表现", subtitle: "快速回看最近几次训练，判断自己是稳态还是波动。", accent: BDColor.primaryBlue) {
                    VStack(spacing: 10) {
                        if recentSessions.isEmpty {
                            Text("还没有可展示的训练记录。")
                                .font(.system(.callout))
                                .foregroundStyle(BDColor.textSecondary)
                        } else {
                            ForEach(recentSessions) { session in
                                BDInteractiveRow(accent: color(for: session.module)) {
                                    HStack(spacing: 12) {
                                        Image(systemName: session.module.systemImage)
                                            .frame(width: 20)
                                            .foregroundStyle(color(for: session.module))
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(session.module.displayName)
                                                .font(.system(.subheadline, weight: .semibold))
                                                .foregroundStyle(BDColor.textPrimary)
                                            Text(appModel.formattedDate(session.endedAt))
                                                .font(.system(.caption))
                                                .foregroundStyle(BDColor.textSecondary)
                                        }
                                    }
                                } trailing: {
                                    InfoPill(title: appModel.formattedDuration(session.duration), accent: color(for: session.module))
                                }
                            }
                        }
                    }
                }

                SurfaceCard(title: "认知维度摘要", subtitle: "目前基于训练记录计算出的能力快照。", accent: BDColor.teal) {
                    VStack(spacing: 10) {
                        ForEach(appModel.cognitiveProfile.dimensions.prefix(4)) { dimension in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(dimension.name)
                                        .font(.system(.subheadline, weight: .semibold))
                                        .foregroundStyle(BDColor.textPrimary)
                                    Spacer()
                                    Text("\(Int(dimension.score))")
                                        .font(.system(.subheadline, weight: .bold))
                                        .foregroundStyle(BDColor.teal)
                                }
                                ProgressView(value: dimension.score / 100.0)
                                    .tint(BDColor.teal)
                            }
                        }
                    }
                }
                .frame(width: 320)
            }
        }
    }

    private func route(for module: TrainingModule) -> AppRoute? {
        AppRoute.readingModules.first(where: { $0.trainingModule == module })
            ?? AppRoute.logicModules.first(where: { $0.trainingModule == module })
            ?? AppRoute.supportModules.first(where: { $0.trainingModule == module })
    }

    private func scheduleLabel(for route: AppRoute) -> String {
        let count = route.trainingModule.map { appModel.statistics.count(for: $0) } ?? 0
        if count == 0 { return "建议开始" }
        if count < 4 { return "建议加练" }
        return "维持频率"
    }

    private func accent(for category: SkillCategory) -> Color {
        switch category {
        case .readingComprehension: return BDColor.gold
        case .logicalReasoning: return BDColor.logicArgumentAccent
        case .memory: return BDColor.nBackAccent
        case .reactionSpeed: return BDColor.choiceRTAccent
        case .inhibitionControl: return BDColor.goNoGoAccent
        case .visualAttentionSearch: return BDColor.primaryBlue
        }
    }

    private func color(for module: TrainingModule) -> Color {
        switch module {
        case .mainIdea: return BDColor.gold
        case .evidenceMap: return BDColor.teal
        case .delayedRecall: return BDColor.green
        case .syllogism: return BDColor.syllogismAccent
        case .logicArgument: return BDColor.logicArgumentAccent
        case .schulte: return BDColor.primaryBlue
        case .visualSearch: return BDColor.visualSearchAccent
        case .nBack: return BDColor.nBackAccent
        case .digitSpan: return BDColor.digitSpanAccent
        case .choiceRT: return BDColor.choiceRTAccent
        case .changeDetection: return BDColor.changeDetectionAccent
        case .corsiBlock: return BDColor.corsiBlockAccent
        case .flanker: return BDColor.flankerAccent
        case .goNoGo: return BDColor.goNoGoAccent
        case .stopSignal: return BDColor.stopSignalAccent
        }
    }
}

struct GameLibraryView: View {
    @Environment(AppModel.self) private var appModel
    @State private var query = ""
    @State private var selectedCategory = "全部"

    private let categories = ["全部", "阅读理解", "逻辑推理", "注意控制", "抑制控制", "工作记忆", "处理速度"]

    var body: some View {
        BDWorkbenchPage(
            title: "训练库",
            subtitle: "按认知能力浏览所有训练模块，查看目标能力、最近状态和推荐频率。"
        ) {
            SurfaceCard(title: "模块筛选", subtitle: "先按能力类别看，再按名称快速定位。", accent: BDColor.teal) {
                VStack(spacing: 14) {
                    TextField("搜索训练模块", text: $query)
                        .bdInputField()

                    BDFilterBar(options: categories, selection: selectedCategory, label: { $0 }, accent: BDColor.teal) {
                        selectedCategory = $0
                    }
                }
            }

            moduleSection(title: "阅读理解", routes: AppRoute.readingModules)
            moduleSection(title: "逻辑推理", routes: AppRoute.logicModules)
            moduleSection(title: "注意控制", routes: AppRoute.attentionModules)
            moduleSection(title: "抑制控制", routes: AppRoute.inhibitionModules)
            moduleSection(title: "工作记忆", routes: AppRoute.memoryModules)
            moduleSection(title: "处理速度", routes: AppRoute.speedModules)
        }
    }

    @ViewBuilder
    private func moduleSection(title: String, routes: [AppRoute]) -> some View {
        let visibleRoutes = routes.filter { route in
            (selectedCategory == "全部" || selectedCategory == title)
                && (query.isEmpty || route.title.localizedCaseInsensitiveContains(query) || route.presentationProfile.shortDescription.localizedCaseInsensitiveContains(query))
        }

        if !visibleRoutes.isEmpty {
            SurfaceCard(title: title, subtitle: "\(visibleRoutes.count) 个模块", accent: accent(for: title)) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                    ForEach(visibleRoutes) { route in
                        BDModuleCard(
                            title: route.title,
                            subtitle: route.presentationProfile.shortDescription,
                            category: title,
                            status: statusLabel(for: route),
                            recommendation: recommendation(for: route),
                            accent: route.presentationProfile.accent,
                            icon: route.systemImage
                        ) {
                            appModel.selectedRoute = route
                        }
                    }
                }
            }
        }
    }

    private func statusLabel(for route: AppRoute) -> String {
        guard let module = route.trainingModule else { return "工作台" }
        return appModel.feedbackStatus(for: module).shortLabel
    }

    private func recommendation(for route: AppRoute) -> String {
        guard let module = route.trainingModule else { return "" }
        let count = appModel.statistics.count(for: module)
        if count == 0 { return "建议本周开始" }
        if count < 3 { return "建议继续补齐" }
        return "维持训练节奏"
    }

    private func accent(for title: String) -> Color {
        switch title {
        case "阅读理解": return BDColor.gold
        case "逻辑推理": return BDColor.logicArgumentAccent
        case "注意控制": return BDColor.primaryBlue
        case "抑制控制": return BDColor.goNoGoAccent
        case "工作记忆": return BDColor.nBackAccent
        case "处理速度": return BDColor.choiceRTAccent
        default: return BDColor.teal
        }
    }
}

struct AnalysisHubView: View {
    @Environment(AppModel.self) private var appModel
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("总览").tag(0)
                Text("历史").tag(1)
                Text("趋势").tag(2)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
            .padding(.top, 24)
            .padding(.horizontal, 32)
            .bdFocusRing(cornerRadius: 12)

            Group {
                switch selectedTab {
                case 0:
                    AnalysisOverviewView()
                case 1:
                    HistoryView()
                default:
                    AnalysisTrendView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

private struct AnalysisOverviewView: View {
    @Environment(AppModel.self) private var appModel

    private var moduleHealthRows: [ModuleHealthRow] {
        TrainingModule.allCases.map { module in
            ModuleHealthRow(
                module: module,
                status: appModel.feedbackStatus(for: module),
                count: appModel.statistics.count(for: module)
            )
        }
        .sorted { lhs, rhs in
            if lhs.status == rhs.status {
                return lhs.count > rhs.count
            }
            return lhs.status.rank < rhs.status.rank
        }
    }

    var body: some View {
        BDWorkbenchPage(title: "分析", subtitle: "长期表现、能力画像与模块健康度。") {
            SurfaceCard(title: "全局概览", subtitle: "把训练节奏、成就和模块覆盖放在一屏里。", accent: BDColor.primaryBlue) {
                HStack(spacing: 14) {
                    BDStatCard(label: "总训练", value: "\(appModel.statistics.totalSessions)", accent: BDColor.primaryBlue, icon: "waveform.path.ecg")
                    BDStatCard(label: "最近主线", value: appModel.statistics.lastReadingModuleName ?? "--", accent: BDColor.gold, icon: "book.fill")
                    BDStatCard(label: "连续训练", value: appModel.streakTracker.streakLabel, accent: BDColor.warm, icon: "flame.fill")
                    BDStatCard(label: "成就", value: "\(appModel.achievementTracker.unlockedCount)/\(appModel.achievementTracker.achievements.count)", accent: BDColor.green, icon: "star.fill")
                }
            }

            HStack(alignment: .top, spacing: 20) {
                SurfaceCard(title: "能力画像", subtitle: "按训练结果估算的核心认知维度。", accent: BDColor.teal) {
                    VStack(spacing: 12) {
                        ForEach(appModel.cognitiveProfile.dimensions) { dimension in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(dimension.name)
                                        .font(.system(.subheadline, weight: .semibold))
                                    Spacer()
                                    Text("\(Int(dimension.score))")
                                        .font(.system(.subheadline, weight: .bold))
                                        .foregroundStyle(BDColor.teal)
                                }
                                ProgressView(value: dimension.score / 100)
                                    .tint(BDColor.teal)
                            }
                        }
                    }
                }

                SurfaceCard(title: "模块健康度", subtitle: "按最近一次表现粗略判断是否稳定。", accent: BDColor.gold) {
                    BDTableSection(title: "最近状态", subtitle: "列对齐后更适合横向扫描模块覆盖与波动。") {
                        Table(moduleHealthRows) {
                            TableColumn("模块") { row in
                                HStack(spacing: 8) {
                                    Image(systemName: row.module.systemImage)
                                        .foregroundStyle(color(for: row.status))
                                    Text(row.module.displayName)
                                        .foregroundStyle(BDColor.textPrimary)
                                }
                            }
                            .width(min: 160, ideal: 180)

                            TableColumn("分类") { row in
                                Text(row.module.skillCategory.displayName)
                                    .foregroundStyle(BDColor.textSecondary)
                            }
                            .width(min: 96, ideal: 120)

                            TableColumn("累计") { row in
                                Text("\(row.count)")
                                    .font(.system(.footnote, design: .monospaced, weight: .semibold))
                                    .foregroundStyle(BDColor.textPrimary)
                            }
                            .width(60)

                            TableColumn("状态") { row in
                                InfoPill(title: row.status.shortLabel, accent: color(for: row.status))
                            }
                            .width(min: 88, ideal: 100)
                        }
                        .frame(minHeight: 320, maxHeight: 360)
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .scrollContentBackground(.hidden)
                    }
                }
                .frame(width: 460)
            }
        }
    }

    private func color(for status: ModuleFeedbackStatus) -> Color {
        switch status {
        case .noData: return BDColor.textSecondary
        case .success: return BDColor.green
        case .warning: return BDColor.warm
        case .error: return BDColor.error
        }
    }
}

private struct AnalysisTrendView: View {
    @Environment(AppModel.self) private var appModel

    private var categoryTrendRows: [CategoryTrendRow] {
        appModel.skillProfile.categoryScores.map {
            CategoryTrendRow(category: $0.category, score: $0.score, moduleCount: $0.moduleCount)
        }
        .sorted { $0.score > $1.score }
    }

    private var moduleCoverageRows: [ModuleCoverageRow] {
        TrainingModule.allCases.map {
            ModuleCoverageRow(module: $0, count: appModel.statistics.count(for: $0))
        }
        .sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.module.displayName < rhs.module.displayName
            }
            return lhs.count > rhs.count
        }
    }

    var body: some View {
        BDWorkbenchPage(title: "趋势", subtitle: "用局部图表和覆盖统计快速判断节奏、偏科与空档。") {
            SurfaceCard(title: "能力类别趋势", subtitle: "基于 adaptive state 的内部得分，用于快速比较强弱。", accent: BDColor.primaryBlue) {
                Chart(categoryTrendRows) { row in
                    BarMark(
                        x: .value("分数", row.score),
                        y: .value("能力", row.category.displayName)
                    )
                    .foregroundStyle(accent(for: row.category))
                    .cornerRadius(6)
                }
                .chartXScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: .stride(by: 20)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(BDColor.borderSubtle)
                        AxisValueLabel {
                            if let value = value.as(Double.self) {
                                Text("\(Int(value))")
                                    .foregroundStyle(BDColor.textSecondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .foregroundStyle(BDColor.textPrimary)
                    }
                }
                .frame(height: 240)
            }

            SurfaceCard(title: "最近训练覆盖", subtitle: "按模块查看当前累计次数，判断是否有长期缺席的训练。", accent: BDColor.gold) {
                BDTableSection(title: "模块覆盖", subtitle: "同时看累计次数、所属维度和当前优先级。") {
                    Table(moduleCoverageRows) {
                        TableColumn("模块") { row in
                            HStack(spacing: 8) {
                                Image(systemName: row.module.systemImage)
                                    .foregroundStyle(accent(for: row.module.skillCategory))
                                Text(row.module.displayName)
                                    .foregroundStyle(BDColor.textPrimary)
                            }
                        }
                        .width(min: 150, ideal: 180)

                        TableColumn("维度") { row in
                            Text(row.module.skillCategory.displayName)
                                .foregroundStyle(BDColor.textSecondary)
                        }
                        .width(min: 90, ideal: 110)

                        TableColumn("累计") { row in
                            Text("\(row.count)")
                                .font(.system(.footnote, design: .monospaced, weight: .semibold))
                                .foregroundStyle(BDColor.textPrimary)
                        }
                        .width(60)

                        TableColumn("建议") { row in
                            Text(recommendation(for: row))
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(recommendationColor(for: row))
                        }
                        .width(min: 92, ideal: 110)
                    }
                    .frame(minHeight: 360, maxHeight: 420)
                    .tableStyle(.inset(alternatesRowBackgrounds: false))
                    .scrollContentBackground(.hidden)
                }
            }
        }
    }

    private func accent(for category: SkillCategory) -> Color {
        switch category {
        case .readingComprehension: return BDColor.gold
        case .logicalReasoning: return BDColor.logicArgumentAccent
        case .memory: return BDColor.nBackAccent
        case .reactionSpeed: return BDColor.choiceRTAccent
        case .inhibitionControl: return BDColor.goNoGoAccent
        case .visualAttentionSearch: return BDColor.primaryBlue
        }
    }

    private func recommendation(for row: ModuleCoverageRow) -> String {
        if row.count == 0 { return "建议开始" }
        if row.count < 3 { return "建议补齐" }
        return "维持频率"
    }

    private func recommendationColor(for row: ModuleCoverageRow) -> Color {
        if row.count == 0 { return BDColor.error }
        if row.count < 3 { return BDColor.warm }
        return BDColor.green
    }
}

private struct ModuleHealthRow: Identifiable {
    let module: TrainingModule
    let status: ModuleFeedbackStatus
    let count: Int

    var id: TrainingModule { module }
}

private struct CategoryTrendRow: Identifiable {
    let category: SkillCategory
    let score: Double
    let moduleCount: Int

    var id: SkillCategory { category }
}

private struct ModuleCoverageRow: Identifiable {
    let module: TrainingModule
    let count: Int

    var id: TrainingModule { module }
}

private extension ModuleFeedbackStatus {
    var rank: Int {
        switch self {
        case .error: return 0
        case .warning: return 1
        case .noData: return 2
        case .success: return 3
        }
    }
}
