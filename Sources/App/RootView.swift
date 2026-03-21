import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        NavigationSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("训练空间")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)

                        ForEach(AppRoute.allCases) { route in
                            Button {
                                appModel.selectedRoute = route
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: route.systemImage)
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(route.title)
                                        Text(route.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .font(.system(.body, design: .rounded, weight: .medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(appModel.selectedRoute == route ? Color.white.opacity(0.72) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("更多训练")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)

                        PlaceholderModuleRow(title: "反应力训练", subtitle: "即将加入", systemImage: "bolt.fill")
                        PlaceholderModuleRow(title: "数字记忆", subtitle: "即将加入", systemImage: "number.square.fill")
                        PlaceholderModuleRow(title: "视觉搜索", subtitle: "即将加入", systemImage: "eye.fill")
                    }
                }
                .padding(18)
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 260)
            .background(sidebarBackground)
        } detail: {
            ZStack {
                detailBackground
                ScrollView {
                    routeView(for: appModel.selectedRoute)
                        .padding(28)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("BrainDrill")
    }

    @ViewBuilder
    private func routeView(for route: AppRoute) -> some View {
        switch route {
        case .training:
            TrainingView()
        case .history:
            HistoryView()
        case .statistics:
            StatisticsView()
        case .settings:
            SettingsView()
        }
    }

    private var sidebarBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.95, green: 0.93, blue: 0.89), Color(red: 0.88, green: 0.90, blue: 0.94)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var detailBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.97, blue: 0.94), Color(red: 0.91, green: 0.94, blue: 0.97)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(red: 0.82, green: 0.87, blue: 0.94).opacity(0.32))
                .frame(width: 320, height: 320)
                .offset(x: 220, y: -220)

            Circle()
                .fill(Color(red: 0.93, green: 0.84, blue: 0.74).opacity(0.22))
                .frame(width: 280, height: 280)
                .offset(x: -260, y: 260)
        }
        .ignoresSafeArea()
    }
}

private struct PlaceholderModuleRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .font(.system(.body, design: .rounded))
        .padding(.vertical, 6)
        .foregroundStyle(.secondary)
    }
}
