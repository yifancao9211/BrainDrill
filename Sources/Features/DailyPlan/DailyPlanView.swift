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

    private var recentSessions: [SessionResult] {
        Array(appModel.sessions.filter { TrainingModule.allCases.contains($0.module) }.prefix(5))
    }

    private var trainedToday: Bool {
        guard let last = appModel.streakTracker.lastTrainingDate else { return false }
        return Calendar.current.isDateInToday(last)
    }

    var body: some View {
        BDWorkbenchPage(
            title: "今日",
            subtitle: "今日打卡、任务与状态一览。",
            maxContentWidth: BDMetrics.contentMaxAnalysisWidth
        ) {
            streakHero
            todayTasksCard
            BDAdaptiveColumns(secondaryWidth: 320) {
                abilityCard
            } secondary: {
                devilRankCard
            }
            recentCard
        }
    }

    // MARK: - 打卡 Hero

    private var streakHero: some View {
        let s = appModel.streakTracker
        return SurfaceCard(
            title: "连续打卡",
            subtitle: trainedToday ? "今天已训练，连胜保住了 🔥" : "今天还没训练 —— 完成任意一项即可点亮今日 🔥",
            accent: BDColor.warm
        ) {
            HStack(alignment: .center, spacing: 20) {
                VStack(spacing: 2) {
                    Text("\(s.currentStreak)")
                        .font(.system(size: 54, weight: .heavy, design: .rounded))
                        .foregroundStyle(BDColor.warm)
                        .contentTransition(.numericText())
                    Text("连续天数").font(.system(.caption, design: .rounded)).foregroundStyle(BDColor.textSecondary)
                }
                Image(systemName: trainedToday ? "flame.fill" : "flame")
                    .font(.system(size: 38))
                    .foregroundStyle(trainedToday ? BDColor.warm : BDColor.textTertiary)
                Spacer()
                HStack(spacing: 18) {
                    heroStat("最长连胜", "\(s.longestStreak) 天")
                    heroStat("累计训练", "\(appModel.statistics.totalSessions) 次")
                    heroStat("成就", "\(appModel.achievementTracker.unlockedCount)/\(appModel.achievementTracker.achievements.count)")
                }
            }
        }
    }

    private func heroStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(BDColor.textPrimary)
            Text(label).font(.system(.caption2, design: .rounded)).foregroundStyle(BDColor.textSecondary)
        }
    }

    // MARK: - 今日任务（每日挑战 + 推荐）

    private var todayTasksCard: some View {
        SurfaceCard(title: "今日任务", subtitle: "完成每日挑战与系统推荐，喂养你的连续打卡。", accent: BDColor.teal) {
            VStack(spacing: 10) {
                let hasReview = appModel.dueReviewCount > 0
                if hasReview {
                    reviewRow
                }
                dailyChallengeRow
                if recommendedRoutes.isEmpty {
                    BDInsightCard(title: "还没有训练记录", bodyText: "先从训练库任意开始一个模块，系统才会根据表现推荐下一步。", accent: BDColor.primaryBlue)
                } else {
                    // 整卡最多 4 行任务：错题复习/每日挑战占掉的行数从推荐里扣。
                    let recBudget = 4 - 1 - (hasReview ? 1 : 0)
                    ForEach(Array(recommendedRoutes.prefix(recBudget).enumerated()), id: \.offset) { index, route in
                        recommendationRow(route, index: index)
                    }
                }
            }
        }
    }

    private var reviewRow: some View {
        BDInteractiveRow(accent: BDColor.error, action: { appModel.startBestReview() }) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BDColor.error.opacity(0.14)).frame(width: 42, height: 42)
                    .overlay { Image(systemName: "tray.full.fill").foregroundStyle(BDColor.error) }
                VStack(alignment: .leading, spacing: 4) {
                    Text("错题复习").font(.system(.headline, weight: .semibold)).foregroundStyle(BDColor.textPrimary)
                    Text("\(appModel.dueReviewCount) 道待复习 · 按遗忘曲线安排").font(.system(.caption)).foregroundStyle(BDColor.textSecondary)
                }
            }
        } trailing: {
            Image(systemName: "play.fill")
                .font(.system(.caption2)).foregroundStyle(.white)
                .frame(width: 28, height: 28).background(Circle().fill(BDColor.error))
        }
    }

    private var dailyChallengeRow: some View {
        let coord = appModel.devilCoord
        return BDInteractiveRow(accent: BDColor.error, action: { appModel.selectedRoute = .devilTraining }) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BDColor.error.opacity(0.14)).frame(width: 42, height: 42)
                    .overlay { Text("👹").font(.system(size: 22)) }
                VStack(alignment: .leading, spacing: 4) {
                    Text("魔鬼 · 每日挑战").font(.system(.headline, weight: .semibold)).foregroundStyle(BDColor.textPrimary)
                    Text(coord.dailyKind.title).font(.system(.caption)).foregroundStyle(BDColor.textSecondary)
                }
            }
        } trailing: {
            HStack(spacing: 8) {
                Text(coord.dailyKind.progressText(coord.dailyProgress))
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(coord.dailyDone ? BDColor.green : BDColor.error)
                Image(systemName: coord.dailyDone ? "checkmark.seal.fill" : "play.fill")
                    .font(.system(.caption2))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(coord.dailyDone ? BDColor.green : BDColor.error))
            }
        }
    }

    private func recommendationRow(_ route: AppRoute, index: Int) -> some View {
        BDInteractiveRow(accent: route.presentationProfile.accent, action: {
            if route.trainingModule?.isQuickStartable == true { appModel.quickStartModule(route) }
            else { appModel.selectedRoute = route }
        }) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(route.presentationProfile.accent.opacity(0.14)).frame(width: 42, height: 42)
                    .overlay { Image(systemName: route.systemImage).foregroundStyle(route.presentationProfile.accent) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.title).font(.system(.headline, weight: .semibold)).foregroundStyle(BDColor.textPrimary)
                    Text(route.presentationProfile.shortDescription).font(.system(.caption)).foregroundStyle(BDColor.textSecondary)
                }
            }
        } trailing: {
            HStack(spacing: 8) {
                Text(scheduleLabel(for: route)).font(.system(.caption, weight: .semibold)).foregroundStyle(route.presentationProfile.accent)
                Image(systemName: route.trainingModule?.isQuickStartable == true ? "play.fill" : "chevron.right")
                    .font(.system(.caption2)).foregroundStyle(.white)
                    .frame(width: 28, height: 28).background(Circle().fill(route.presentationProfile.accent))
            }
        }
    }

    // MARK: - 综合实力

    private var abilityCard: some View {
        let profile = appModel.skillProfile
        return SurfaceCard(title: "综合实力", subtitle: "基于你已训练模块的难度与正确率估计；未训练的不计入，可信度随训练量上升。", accent: BDColor.primaryBlue) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(profile.coverage > 0 ? "\(Int(profile.overallInternalScore))" : "—")
                        .font(.system(size: 42, weight: .heavy, design: .rounded)).foregroundStyle(BDColor.primaryBlue)
                    Text("/ 100 综合评分").font(.system(.caption, design: .rounded)).foregroundStyle(BDColor.textSecondary)
                    Spacer()
                    Text("可信度 \(Int(profile.overallConfidence * 100))% · 覆盖 \(Int(profile.coverage * 4))/4")
                        .font(.system(.caption2, design: .rounded)).foregroundStyle(BDColor.textTertiary)
                }
                ForEach(profile.categoryScores) { cat in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(cat.category.displayName).font(.system(.subheadline, weight: .semibold)).foregroundStyle(BDColor.textPrimary)
                            Spacer()
                            if cat.hasData {
                                Text("\(Int(cat.score))")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(accent(for: cat.category))
                                Text("可信 \(Int(cat.reliability * 100))%")
                                    .font(.system(.caption2, design: .rounded)).foregroundStyle(BDColor.textTertiary)
                            } else {
                                Text("暂无数据").font(.system(.caption, design: .rounded)).foregroundStyle(BDColor.textTertiary)
                            }
                        }
                        ProgressView(value: cat.hasData ? cat.score / 100.0 : 0).tint(accent(for: cat.category))
                            .opacity(cat.hasData ? 1 : 0.4)
                    }
                }
            }
        }
    }

    // MARK: - 魔鬼段位

    private var devilRankCard: some View {
        let coord = appModel.devilCoord
        let rank = coord.rank
        let cur = coord.totalPower
        let hi = rank.next?.threshold ?? max(cur, rank.threshold + 1)
        let frac = rank.next == nil ? 1.0 : Double(cur - rank.threshold) / Double(max(1, hi - rank.threshold))
        return SurfaceCard(title: "魔鬼段位", subtitle: "玩魔鬼锻炼积累魔力值晋升。", accent: BDColor.error) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(rank.symbol).font(.system(size: 34))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rank.displayName).font(.system(.headline, design: .rounded, weight: .bold)).foregroundStyle(BDColor.textPrimary)
                        Text("魔力值 \(cur)").font(.system(.caption, design: .rounded)).foregroundStyle(BDColor.textSecondary)
                    }
                    Spacer()
                }
                ProgressView(value: frac).tint(BDColor.error)
                Text(rank.next.map { "距「\($0.displayName)」还差 \(max(0, hi - cur))" } ?? "已至巅峰 · 魔王")
                    .font(.system(.caption, design: .rounded)).foregroundStyle(BDColor.textSecondary)
                Button("进入魔鬼锻炼") { appModel.selectedRoute = .devilTraining }
                    .buttonStyle(BDSecondaryButton(accent: BDColor.error))
            }
        }
    }

    // MARK: - 最近表现

    private var recentCard: some View {
        SurfaceCard(title: "最近表现", subtitle: "回看最近几次训练，判断状态是稳是波动。", accent: BDColor.primaryBlue) {
            VStack(spacing: 10) {
                if recentSessions.isEmpty {
                    Text("还没有可展示的训练记录。").font(.system(.callout)).foregroundStyle(BDColor.textSecondary)
                } else {
                    ForEach(recentSessions) { session in
                        BDInteractiveRow(accent: color(for: session.module)) {
                            HStack(spacing: 12) {
                                Image(systemName: sessionIcon(session)).frame(width: 20).foregroundStyle(color(for: session.module))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(sessionTitle(session)).font(.system(.subheadline, weight: .semibold)).foregroundStyle(BDColor.textPrimary)
                                    Text(appModel.formattedDate(session.endedAt)).font(.system(.caption)).foregroundStyle(BDColor.textSecondary)
                                }
                            }
                        } trailing: {
                            InfoPill(title: appModel.formattedDuration(session.duration), accent: color(for: session.module))
                        }
                    }
                }
            }
        }
    }

    /// 魔鬼锻炼的会话按具体小游戏显示名称/图标，其余按模块。
    private func sessionTitle(_ s: SessionResult) -> String {
        if let m = s.devilGameMetrics { return m.game.displayName }
        return s.module.displayName
    }

    private func sessionIcon(_ s: SessionResult) -> String {
        if let m = s.devilGameMetrics { return m.game.systemImage }
        return s.module.systemImage
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
        case .logicReasoning: return BDColor.syllogismAccent
        case .civilExam: return BDColor.teal
        case .devilTraining: return BDColor.error
        case .schulte: return BDColor.primaryBlue
        case .nBack: return BDColor.nBackAccent
        case .digitSpan: return BDColor.digitSpanAccent
        case .changeDetection: return BDColor.changeDetectionAccent
        case .corsiBlock: return BDColor.corsiBlockAccent
        }
    }
}

struct GameLibraryView: View {
    @Environment(AppModel.self) private var appModel
    @State private var query = ""
    @State private var selectedCategory = "全部"

    private let categories = ["全部", "阅读理解", "逻辑推理", "注意控制", "工作记忆", "魔鬼锻炼"]

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
            moduleSection(title: "工作记忆", routes: AppRoute.memoryModules)
            devilSection()
        }
    }

    /// 魔鬼锻炼区：展示三个子游戏卡片，点卡直接开打。
    @ViewBuilder
    private func devilSection() -> some View {
        let games = DevilGameKind.allCases.filter { game in
            (selectedCategory == "全部" || selectedCategory == "魔鬼锻炼")
                && (query.isEmpty || game.displayName.localizedCaseInsensitiveContains(query) || game.subtitle.localizedCaseInsensitiveContains(query))
        }
        if !games.isEmpty {
            SurfaceCard(title: "魔鬼锻炼", subtitle: "\(games.count) 个限时小游戏", accent: BDColor.error) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                    ForEach(games) { game in
                        let best = appModel.devilCoord.bestScore(for: game)
                        let stars = appModel.devilCoord.stars(for: game)
                        BDModuleCard(
                            title: game.displayName,
                            subtitle: game.subtitle,
                            category: "魔鬼锻炼",
                            status: best > 0 ? "最佳 \(best)" : "未玩",
                            recommendation: stars > 0 ? "⭐ \(stars)" : "开始挑战",
                            accent: BDColor.error,
                            icon: game.systemImage,
                            action: {
                                appModel.startDevilGame(game)
                                appModel.selectedRoute = .devilTraining
                            },
                            quickStartAction: {
                                appModel.startDevilGame(game)
                                appModel.selectedRoute = .devilTraining
                            }
                        )
                    }
                }
            }
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
                            icon: route.systemImage,
                            action: {
                                appModel.selectedRoute = route
                            },
                            quickStartAction: route.trainingModule?.isQuickStartable == true ? {
                                appModel.quickStartModule(route)
                            } : nil
                        )
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
        case "工作记忆": return BDColor.nBackAccent
        case "魔鬼锻炼": return BDColor.error
        default: return BDColor.teal
        }
    }
}

/// 控制台与分析合并后的主页：今日（仪表盘）/ 总览 / 历史 / 趋势 四个分段。
struct ConsoleHubView: View {
    @Environment(AppModel.self) private var appModel
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("今日").tag(0)
                Text("总览").tag(1)
                Text("历史").tag(2)
                Text("趋势").tag(3)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 480)
            .padding(.top, 24)
            .padding(.horizontal, 32)
            .bdFocusRing(cornerRadius: 12)

            Group {
                switch selectedTab {
                case 0:
                    DailyPlanView()
                case 1:
                    AnalysisOverviewView()
                case 2:
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
                BDAdaptiveStatRow {
                    BDStatCard(label: "完成次数", value: "\(appModel.statistics.totalSessions)", accent: BDColor.primaryBlue, icon: "waveform.path.ecg")
                    BDStatCard(label: "最近主线", value: appModel.statistics.lastReadingModuleName ?? "--", accent: BDColor.gold, icon: "book.fill")
                    BDStatCard(label: "连续训练", value: appModel.streakTracker.streakLabel, accent: BDColor.warm, icon: "flame.fill")
                    BDStatCard(label: "成就", value: "\(appModel.achievementTracker.unlockedCount)/\(appModel.achievementTracker.achievements.count)", accent: BDColor.green, icon: "star.fill")
                }
            }

            BDAdaptiveColumns(secondaryWidth: 460) {
                SurfaceCard(title: "能力画像", subtitle: "已训练模块的能力估计（θ）与可信度；未训练不计入。", accent: BDColor.teal) {
                    VStack(spacing: 12) {
                        ForEach(appModel.skillProfile.categoryScores) { cat in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(cat.category.displayName)
                                        .font(.system(.subheadline, weight: .semibold))
                                    Spacer()
                                    if cat.hasData {
                                        Text("\(Int(cat.score))")
                                            .font(.system(.subheadline, weight: .bold))
                                            .foregroundStyle(BDColor.teal)
                                        Text("· 可信 \(Int(cat.reliability * 100))% · \(cat.trainedCount)/\(cat.totalCount) 模块")
                                            .font(.system(.caption2, design: .rounded)).foregroundStyle(BDColor.textTertiary)
                                    } else {
                                        Text("暂无数据").font(.system(.caption)).foregroundStyle(BDColor.textTertiary)
                                    }
                                }
                                ProgressView(value: cat.hasData ? cat.score / 100 : 0)
                                    .tint(BDColor.teal).opacity(cat.hasData ? 1 : 0.4)
                            }
                        }
                    }
                }
            } secondary: {
                SurfaceCard(title: "模块健康度", subtitle: "按最近一次表现粗略判断是否稳定。", accent: BDColor.gold) {
                    BDTableSection(title: "最近状态", subtitle: "列对齐后更适合横向扫描模块覆盖与波动。") {
                        #if os(iOS)
                        VStack(spacing: 8) {
                            ForEach(moduleHealthRows) { row in
                                HStack(spacing: 10) {
                                    Image(systemName: row.module.systemImage)
                                        .foregroundStyle(color(for: row.status))
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.module.displayName)
                                            .font(.system(.subheadline, weight: .medium))
                                        Text(row.module.skillCategory.displayName)
                                            .font(.system(.caption))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(row.count)")
                                        .font(.system(.footnote, design: .monospaced, weight: .semibold))
                                    InfoPill(title: row.status.shortLabel, accent: color(for: row.status))
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        #else
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
                        #endif
                    }
                }
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
        appModel.skillProfile.categoryScores
            .filter { $0.hasData }
            .map { CategoryTrendRow(category: $0.category, score: $0.score, moduleCount: $0.trainedCount) }
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

    /// 每次训练换算成 0–100 的能力 θ（与综合实力同一口径），按时间排序，用于趋势折线。
    private var thetaTrendPoints: [ThetaTrendPoint] {
        appModel.sessions
            .filter { TrainingModule.allCases.contains($0.module) }
            .sorted { $0.endedAt < $1.endedAt }
            .enumerated()
            .map { idx, s in
                let level = AdaptiveScoring.nextRecommendedLevel(for: s)
                let perf = AdaptiveScoring.performanceIndex(for: s)
                return ThetaTrendPoint(
                    order: idx,
                    date: s.endedAt,
                    category: s.module.skillCategory,
                    theta: SkillEstimator.sessionTheta(module: s.module, level: level, performance: perf)
                )
            }
    }

    var body: some View {
        BDWorkbenchPage(title: "趋势", subtitle: "用局部图表和覆盖统计快速判断节奏、偏科与空档。") {
            thetaTrendCard
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
                    #if os(iOS)
                    VStack(spacing: 8) {
                        ForEach(moduleCoverageRows) { row in
                            HStack(spacing: 10) {
                                Image(systemName: row.module.systemImage)
                                    .foregroundStyle(accent(for: row.module.skillCategory))
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.module.displayName)
                                        .font(.system(.subheadline, weight: .medium))
                                    Text(row.module.skillCategory.displayName)
                                        .font(.system(.caption))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(row.count)")
                                    .font(.system(.footnote, design: .monospaced, weight: .semibold))
                                Text(recommendation(for: row))
                                    .font(.system(.caption, weight: .semibold))
                                    .foregroundStyle(recommendationColor(for: row))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    #else
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
                    #endif
                }
            }
        }
    }

    @ViewBuilder
    private var thetaTrendCard: some View {
        let points = thetaTrendPoints
        SurfaceCard(title: "能力 θ 趋势", subtitle: "每次训练换算成 0–100 的能力 θ，看各维度随时间的走势。", accent: BDColor.teal) {
            if points.count < 2 {
                Text("训练记录还太少，多练几次就能看到趋势曲线。")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(BDColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                let cats = SkillCategory.allCases.filter { c in points.contains { $0.category == c } }
                Chart(points) { p in
                    LineMark(
                        x: .value("第几次", p.order + 1),
                        y: .value("θ", p.theta)
                    )
                    .foregroundStyle(by: .value("维度", p.category.displayName))
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("第几次", p.order + 1),
                        y: .value("θ", p.theta)
                    )
                    .foregroundStyle(by: .value("维度", p.category.displayName))
                    .symbolSize(18)
                }
                .chartForegroundStyleScale(domain: cats.map(\.displayName), range: cats.map { accent(for: $0) })
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: .stride(by: 25)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(BDColor.borderSubtle)
                        AxisValueLabel {
                            if let v = value.as(Int.self) { Text("\(v)").foregroundStyle(BDColor.textSecondary) }
                        }
                    }
                }
                .frame(height: 240)
            }
        }
    }

    private func accent(for category: SkillCategory) -> Color {
        switch category {
        case .readingComprehension: return BDColor.gold
        case .logicalReasoning: return BDColor.logicArgumentAccent
        case .memory: return BDColor.nBackAccent
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

private struct ThetaTrendPoint: Identifiable {
    let id = UUID()
    let order: Int
    let date: Date
    let category: SkillCategory
    let theta: Double
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
