import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @State private var sidebarSelection: AppRoute?

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 280)
                .background(BDColor.sidebarBackground)
        } detail: {
            VStack(spacing: 12) {
                BDScreenContextBar(
                    route: appModel.selectedRoute,
                    status: appModel.currentStatusMessage,
                    isTrainingActive: appModel.isSelectedTrainingActive
                )

                ZStack {
                    detailBackground
                    detailContent
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("BrainDrill")
        .onAppear { sidebarSelection = appModel.selectedRoute }
        .onChange(of: sidebarSelection) { _, newValue in
            guard let newValue else { return }
            withAnimation(.snappy(duration: 0.20)) {
                appModel.selectedRoute = newValue
            }
        }
        .onChange(of: appModel.selectedRoute) { _, newValue in
            sidebarSelection = newValue
        }
    }

    private var sidebar: some View {
        List(selection: $sidebarSelection) {
            sidebarSection(title: "阅读训练", routes: AppRoute.readingModules)
            sidebarSection(title: "支撑训练", routes: AppRoute.supportModules)
            sidebarSection(title: "工具", routes: AppRoute.tools)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .allowsHitTesting(!appModel.isSelectedTrainingActive)
        .opacity(appModel.isSelectedTrainingActive ? 0.35 : 1)
        .saturation(appModel.isSelectedTrainingActive ? 0.8 : 1)
        .blur(radius: appModel.isSelectedTrainingActive ? 1.0 : 0)
        .animation(.easeInOut(duration: 0.2), value: appModel.isAnyModuleActive)
    }

    private func sidebarSection(title: String, routes: [AppRoute]) -> some View {
        Section {
            ForEach(routes) { route in
                sidebarRow(route)
                    .tag(route)
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    .listRowBackground(Color.clear)
            }
        } header: {
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(BDColor.textSecondary)
        }
    }

    private func sidebarRow(_ route: AppRoute) -> some View {
        let isSelected = appModel.selectedRoute == route
        let status = route.trainingModule.map(appModel.feedbackStatus(for:))
        return HStack(spacing: 12) {
            Image(systemName: route.systemImage)
                .font(.system(.callout, weight: .semibold))
                .foregroundStyle(route.presentationProfile.accent)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(route.title)
                    .font(.system(.callout, design: .rounded, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(BDColor.textPrimary)
                if isSelected {
                    Text(route.presentationProfile.subtitle)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(BDColor.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if route.isModule {
                Circle()
                    .fill(sidebarIndicatorColor(status: status, accent: route.presentationProfile.accent, isSelected: isSelected))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? BDColor.sidebarSelected : Color.clear)
        )
    }

    private func sidebarIndicatorColor(status: ModuleFeedbackStatus?, accent: Color, isSelected: Bool) -> Color {
        switch status {
        case .success:
            return BDColor.green.opacity(isSelected ? 0.95 : 0.8)
        case .warning:
            return BDColor.warm.opacity(isSelected ? 0.95 : 0.8)
        case .error:
            return BDColor.error.opacity(isSelected ? 0.95 : 0.8)
        case .noData, .none:
            return accent.opacity(isSelected ? 0.9 : 0.24)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if appModel.selectedRoute.isModule {
            moduleDetailContent
        } else {
            workbenchDetailContent
        }
    }

    @ViewBuilder
    private var moduleDetailContent: some View {
        switch appModel.selectedRoute {
        case .mainIdea:
            readingModuleScroll {
                MainIdeaTrainingView()
            }
        case .evidenceMap:
            readingModuleScroll {
                EvidenceMapTrainingView()
            }
        case .delayedRecall:
            readingModuleScroll {
                DelayedRecallTrainingView()
            }
        case .schulte:
            SchulteTrainingView()
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        case .visualSearch:
            VisualSearchTrainingView()
        case .nBack:
            NBackTrainingView()
        default:
            EmptyView()
        }
    }

    private func readingModuleScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.visible)
    }

    private var workbenchDetailContent: some View {
        ScrollView {
            Group {
                switch appModel.selectedRoute {
                case .home:
                    DailyPlanView()
                case .history:
                    HistoryView()
                case .settings:
                    SettingsView()
                default:
                    EmptyView()
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }

    private var detailBackground: some View {
        ZStack {
            BDColor.contentBackground
            Circle()
                .fill(appModel.selectedRoute.presentationProfile.accent.opacity(0.05))
                .frame(width: 280, height: 280)
                .blur(radius: 40)
                .offset(x: 180, y: -140)
            Rectangle()
                .fill(BDColor.panelSecondaryFill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(1)
        }
        .ignoresSafeArea()
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
