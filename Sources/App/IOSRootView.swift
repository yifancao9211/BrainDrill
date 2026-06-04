#if os(iOS)
import SwiftUI

struct IOSRootView: View {
    @Environment(AppModel.self) private var appModel
    @State private var selectedTab: IOSTab = .dashboard

    enum IOSTab: String, CaseIterable {
        case dashboard, library, materials, analysis, settings

        var title: String {
            switch self {
            case .dashboard: "控制台"
            case .library: "训练库"
            case .materials: "素材"
            case .analysis: "分析"
            case .settings: "设置"
            }
        }

        var icon: String {
            switch self {
            case .dashboard: "rectangle.stack.fill"
            case .library: "square.grid.2x2.fill"
            case .materials: "tray.full.fill"
            case .analysis: "chart.xyaxis.line"
            case .settings: "slider.horizontal.3"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(IOSTab.dashboard.title,
                systemImage: IOSTab.dashboard.icon,
                value: .dashboard) {
                NavigationStack {
                    DailyPlanView()
                        .navigationTitle("控制台")
                }
            }

            Tab(IOSTab.library.title,
                systemImage: IOSTab.library.icon,
                value: .library) {
                NavigationStack {
                    IOSTrainingLibraryView()
                        .navigationTitle("训练库")
                }
            }

            Tab(IOSTab.materials.title,
                systemImage: IOSTab.materials.icon,
                value: .materials) {
                NavigationStack {
                    MaterialsManageView()
                        .navigationTitle("素材")
                }
            }

            Tab(IOSTab.analysis.title,
                systemImage: IOSTab.analysis.icon,
                value: .analysis) {
                NavigationStack {
                    AnalysisHubView()
                        .navigationTitle("分析")
                }
            }

            Tab(IOSTab.settings.title,
                systemImage: IOSTab.settings.icon,
                value: .settings) {
                NavigationStack {
                    SettingsView()
                        .navigationTitle("设置")
                }
            }
        }
        .tint(BDColor.primaryBlue)
    }
}

// MARK: - iOS Training Library

/// A training library view optimised for iPhone with NavigationLink drill-down.
struct IOSTrainingLibraryView: View {
    @Environment(AppModel.self) private var appModel

    private static let categories: [(title: String, icon: String, routes: [AppRoute], accent: Color)] = [
        ("阅读理解", "text.book.closed.fill", AppRoute.readingModules, BDColor.gold),
        ("逻辑推理", "brain.fill", AppRoute.logicModules, BDColor.logicArgumentAccent),
        ("注意控制", "eye.fill", AppRoute.attentionModules, BDColor.primaryBlue),
        ("工作记忆", "memorychip.fill", AppRoute.memoryModules, BDColor.nBackAccent),
    ]

    var body: some View {
        List {
            ForEach(Self.categories, id: \.title) { cat in
                Section {
                    ForEach(cat.routes) { route in
                        NavigationLink {
                            IOSModuleContainerView(route: route)
                                .navigationTitle(route.title)
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: route.systemImage)
                                    .font(.system(.body, weight: .semibold))
                                    .foregroundStyle(cat.accent)
                                    .frame(width: 32, height: 32)
                                    .background(cat.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(route.title)
                                        .font(.system(.headline, weight: .semibold))
                                    Text(route.presentationProfile.shortDescription)
                                        .font(.system(.caption))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Label(cat.title, systemImage: cat.icon)
                        .foregroundStyle(cat.accent)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - iOS Module Container

/// Wraps each training module view for iPhone presentation.
struct IOSModuleContainerView: View {
    @Environment(AppModel.self) private var appModel
    let route: AppRoute

    var body: some View {
        Group {
            switch route {
            case .mainIdea:
                ScrollView { MainIdeaTrainingView().padding() }
            case .evidenceMap:
                ScrollView { EvidenceMapTrainingView().padding() }
            case .delayedRecall:
                ScrollView { DelayedRecallTrainingView().padding() }
            case .syllogism:
                SyllogismTrainingView()
            case .logicArgument:
                LogicArgumentTrainingView()
            case .schulte:
                SchulteTrainingView()
            case .nBack:
                NBackTrainingView()
            case .digitSpan:
                DigitSpanTrainingView()
            case .corsiBlock:
                CorsiBlockTrainingView()
            case .changeDetection:
                ChangeDetectionTrainingView()
            default:
                Text("该模块暂未适配")
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            appModel.selectedRoute = route
        }
    }
}
#endif
