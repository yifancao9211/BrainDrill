import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 260)
                .background(colorScheme == .dark ? BDGradient.sidebarDark : BDGradient.sidebarLight)
        } detail: {
            ZStack {
                detailBackground
                detailContent
            }
        }
        .navigationTitle("BrainDrill")
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sidebarSection(title: "记忆力", routes: AppRoute.memoryModules)
                sidebarSection(title: "反应力", routes: AppRoute.reactionModules)
                sidebarSection(title: "视觉注意", routes: AppRoute.visualModules)
                sidebarSection(title: "工具", routes: AppRoute.tools)
            }
            .padding(18)
        }
        .allowsHitTesting(!appModel.isAnyModuleActive)
        .opacity(appModel.isAnyModuleActive ? 0.4 : 1)
        .animation(.easeInOut(duration: 0.2), value: appModel.isAnyModuleActive)
    }

    private func sidebarSection(title: String, routes: [AppRoute]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            ForEach(routes) { route in
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        appModel.selectedRoute = route
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: route.systemImage)
                            .foregroundStyle(accentColor(for: route))
                            .frame(width: 20)
                        Text(route.title)
                        Spacer()
                    }
                    .font(.system(.callout, design: .rounded, weight: appModel.selectedRoute == route ? .semibold : .regular))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(appModel.selectedRoute == route ? BDColor.sidebarSelected : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func accentColor(for route: AppRoute) -> Color {
        switch route {
        case .schulte:         BDColor.primaryBlue
        case .flanker:         BDColor.flankerAccent
        case .goNoGo:          BDColor.goNoGoAccent
        case .nBack:           BDColor.nBackAccent
        case .digitSpan:       BDColor.digitSpanAccent
        case .choiceRT:        BDColor.choiceRTAccent
        case .changeDetection: BDColor.changeDetectionAccent
        case .visualSearch:    BDColor.visualSearchAccent
        case .corsiBlock:      BDColor.corsiBlockAccent
        case .stopSignal:      BDColor.stopSignalAccent
        case .dailyPlan:       BDColor.gold
        case .statistics:      BDColor.green
        case .aiAnalyst:       BDColor.teal
        case .history:         BDColor.warm
        case .settings:        .secondary
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch appModel.selectedRoute {
        case .dailyPlan:
            ScrollView { DailyPlanView().padding(28) }.scrollIndicators(.hidden)
        case .schulte:
            SchulteTrainingView()
        case .flanker:
            FlankerTrainingView()
        case .goNoGo:
            GoNoGoTrainingView()
        case .nBack:
            NBackTrainingView()
        case .digitSpan:
            DigitSpanTrainingView()
        case .choiceRT:
            ChoiceRTTrainingView()
        case .changeDetection:
            ChangeDetectionTrainingView()
        case .visualSearch:
            VisualSearchTrainingView()
        case .corsiBlock:
            CorsiBlockTrainingView()
        case .stopSignal:
            StopSignalTrainingView()
        case .history:
            ScrollView { HistoryView().padding(28) }.scrollIndicators(.hidden)
        case .statistics:
            ScrollView { StatisticsView().padding(28) }.scrollIndicators(.hidden)
        case .aiAnalyst:
            ScrollView { AIAnalystView().padding(28) }.scrollIndicators(.hidden)
        case .settings:
            ScrollView { SettingsView().padding(28) }.scrollIndicators(.hidden)
        }
    }

    private var detailBackground: some View {
        ZStack {
            (colorScheme == .dark ? BDGradient.detailDark : BDGradient.detailLight)
            Circle()
                .fill(BDColor.primaryBlue.opacity(colorScheme == .dark ? 0.06 : 0.12))
                .frame(width: 320, height: 320)
                .offset(x: 220, y: -220)
            Circle()
                .fill(BDColor.warm.opacity(colorScheme == .dark ? 0.04 : 0.08))
                .frame(width: 280, height: 280)
                .offset(x: -260, y: 260)
        }
        .ignoresSafeArea()
    }
}
