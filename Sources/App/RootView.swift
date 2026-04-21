import SwiftUI

enum BDWorkspaceDestination: String, CaseIterable, Identifiable, Hashable {
    case controlCenter
    case trainingLibrary
    case analysis
    case materials
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .controlCenter: return "控制台"
        case .trainingLibrary: return "训练库"
        case .analysis: return "分析"
        case .materials: return "素材"
        case .settings: return "设置"
        }
    }

    var subtitle: String {
        switch self {
        case .controlCenter: return "推荐训练与今日状态"
        case .trainingLibrary: return "全部模块与分类入口"
        case .analysis: return "总览、历史与趋势"
        case .materials: return "阅读素材工作台"
        case .settings: return "训练与应用参数"
        }
    }

    var systemImage: String {
        switch self {
        case .controlCenter: return "rectangle.stack.fill"
        case .trainingLibrary: return "square.grid.2x2.fill"
        case .analysis: return "chart.xyaxis.line"
        case .materials: return "tray.full.fill"
        case .settings: return "slider.horizontal.3"
        }
    }

    var accent: Color {
        switch self {
        case .controlCenter: return BDColor.primaryBlue
        case .trainingLibrary: return BDColor.teal
        case .analysis: return BDColor.gold
        case .materials: return BDColor.warm
        case .settings: return BDColor.textSecondary
        }
    }

    var route: AppRoute {
        switch self {
        case .controlCenter: return .home
        case .trainingLibrary: return .mainIdea
        case .analysis: return .history
        case .materials: return .materialsWorkbench
        case .settings: return .settings
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @State private var sidebarSelection: SidebarItem? = .workspace(.controlCenter)

    enum SidebarItem: Hashable {
        case workspace(BDWorkspaceDestination)
        case category(String) // key like "reading", "logic", etc.
    }

    private static let categories: [(key: String, title: String, icon: String, routes: [AppRoute], accent: Color)] = [
        ("reading", "阅读理解", "text.book.closed.fill", AppRoute.readingModules, BDColor.gold),
        ("logic", "逻辑推理", "brain.fill", AppRoute.logicModules, BDColor.logicArgumentAccent),
        ("attention", "注意控制", "eye.fill", AppRoute.attentionModules, BDColor.primaryBlue),
        ("inhibition", "抑制控制", "hand.raised.fill", AppRoute.inhibitionModules, BDColor.goNoGoAccent),
        ("memory", "工作记忆", "memorychip.fill", AppRoute.memoryModules, BDColor.nBackAccent),
        ("speed", "处理速度", "bolt.fill", AppRoute.speedModules, BDColor.choiceRTAccent),
    ]

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
        }
        .frame(minWidth: 1060, minHeight: 720)
        .onAppear {
            syncSelection(from: appModel.selectedRoute)
        }
        .onChange(of: appModel.selectedRoute) { _, route in
            syncSelection(from: route)
        }
        .onChange(of: sidebarSelection) { _, item in
            guard let item else { return }
            switch item {
            case .workspace, .category:
                // Clear any active module training; detail resolves from sidebarSelection
                if appModel.selectedRoute.isModule {
                    appModel.selectedRoute = .home
                }
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $sidebarSelection) {
            Section("工作台") {
                ForEach(BDWorkspaceDestination.allCases) { destination in
                    Label {
                        Text(destination.title)
                    } icon: {
                        Image(systemName: destination.systemImage)
                            .foregroundStyle(sidebarSelection == .workspace(destination) ? destination.accent : .secondary)
                    }
                    .tag(SidebarItem.workspace(destination))
                }
            }

            Section("训练类别") {
                ForEach(Self.categories, id: \.key) { cat in
                    Label {
                        HStack {
                            Text(cat.title)
                            Spacer()
                            Text("\(cat.routes.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: cat.icon)
                            .foregroundStyle(cat.accent)
                    }
                    .tag(SidebarItem.category(cat.key))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 280)
        .navigationTitle("BrainDrill")
        .safeAreaInset(edge: .bottom) {
            sidebarStatusFooter
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
        }
    }

    private var sidebarStatusFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当前状态")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("已训练")
                        .font(.system(.caption2))
                        .foregroundStyle(.tertiary)
                    Text("\(appModel.statistics.totalSessions)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text("连续")
                        .font(.system(.caption2))
                        .foregroundStyle(.tertiary)
                    Text(appModel.streakTracker.streakLabel)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Spacer()
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailContent: some View {
        if appModel.selectedRoute.isModule {
            // Active module training
            moduleDetailContent
                .padding(16)
        } else if case .category(let key) = sidebarSelection {
            // Category module picker
            if let cat = Self.categories.first(where: { $0.key == key }) {
                categoryModuleList(cat: cat)
            }
        } else {
            // Workspace page (控制台/训练库/分析/素材/设置)
            workspaceContent
        }
    }

    private func categoryModuleList(cat: (key: String, title: String, icon: String, routes: [AppRoute], accent: Color)) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cat.title)
                        .font(.system(.title2, weight: .bold))
                    Text("选择一个模块开始训练")
                        .font(.system(.callout))
                        .foregroundStyle(.secondary)
                }

                ForEach(cat.routes) { route in
                    Button {
                        appModel.selectedRoute = route
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: route.systemImage)
                                .font(.system(.title3, weight: .semibold))
                                .foregroundStyle(cat.accent)
                                .frame(width: 36, height: 36)
                                .background(cat.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(route.title)
                                    .font(.system(.headline, weight: .semibold))
                                    .foregroundStyle(BDColor.textPrimary)
                                Text(route.presentationProfile.shortDescription)
                                    .font(.system(.caption))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(BDColor.panelFill, in: RoundedRectangle(cornerRadius: BDMetrics.cornerRadiusMedium, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: BDMetrics.cornerRadiusMedium, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var workspaceContent: some View {
        let destination = currentWorkspaceDestination
        Group {
            switch destination {
            case .controlCenter:
                DailyPlanView()
            case .trainingLibrary:
                GameLibraryView()
            case .analysis:
                AnalysisHubView()
            case .materials:
                MaterialsWorkbenchView()
            case .settings:
                SettingsView()
            }
        }
        .frame(maxWidth: workspaceContentMaxWidth(for: destination), alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var moduleDetailContent: some View {
        switch appModel.selectedRoute {
        case .mainIdea:
            readingModuleScroll { MainIdeaTrainingView() }
        case .evidenceMap:
            readingModuleScroll { EvidenceMapTrainingView() }
        case .delayedRecall:
            readingModuleScroll { DelayedRecallTrainingView() }
        case .syllogism:
            SyllogismTrainingView()
        case .logicArgument:
            LogicArgumentTrainingView()
        case .schulte:
            SchulteTrainingView()
        case .visualSearch:
            VisualSearchTrainingView()
        case .flanker:
            FlankerTrainingView()
        case .goNoGo:
            GoNoGoTrainingView()
        case .stopSignal:
            StopSignalTrainingView()
        case .nBack:
            NBackTrainingView()
        case .digitSpan:
            DigitSpanTrainingView()
        case .corsiBlock:
            CorsiBlockTrainingView()
        case .changeDetection:
            ChangeDetectionTrainingView()
        case .choiceRT:
            ChoiceRTTrainingView()
        default:
            EmptyView()
        }
    }

    private func readingModuleScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(.vertical, 8)
                .frame(maxWidth: BDMetrics.contentMaxReadableWidth, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.visible)
    }

    // MARK: - Helpers

    private var currentWorkspaceDestination: BDWorkspaceDestination {
        switch sidebarSelection {
        case .workspace(let dest): return dest
        case .category: return .trainingLibrary
        case .none: return .controlCenter
        }
    }

    private func workspaceContentMaxWidth(for destination: BDWorkspaceDestination) -> CGFloat {
        switch destination {
        case .controlCenter, .analysis:
            return BDMetrics.contentMaxAnalysisWidth
        case .trainingLibrary:
            return BDMetrics.contentMaxWorkbenchWidth
        case .materials, .settings:
            return BDMetrics.contentMaxReadableWidth
        }
    }

    private var activeContextRoute: AppRoute {
        if appModel.selectedRoute.isModule {
            return appModel.selectedRoute
        }
        return currentWorkspaceDestination.route
    }

    private func syncSelection(from route: AppRoute) {
        if route.isModule {
            // Find which category contains this route
            for cat in Self.categories {
                if cat.routes.contains(route) {
                    sidebarSelection = .category(cat.key)
                    return
                }
            }
            sidebarSelection = .workspace(.trainingLibrary)
            return
        }

        // If sidebar is already on a category, don't override it
        // (category view sets route to .home to clear stale module)
        if case .category = sidebarSelection {
            return
        }

        switch route {
        case .home:
            sidebarSelection = .workspace(.controlCenter)
        case .materialsWorkbench:
            sidebarSelection = .workspace(.materials)
        case .settings:
            sidebarSelection = .workspace(.settings)
        case .history:
            sidebarSelection = .workspace(.analysis)
        default:
            break
        }
    }
}
