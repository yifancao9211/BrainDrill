import SwiftUI

struct DailyPlanView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        BDWorkbenchPage(title: "首页", subtitle: "阅读主线优先，支撑训练做补位。") {
            VStack(spacing: 18) {
                overviewCard
                recommendedCard
                activeModulesCard
            }
        }
    }

    private var overviewCard: some View {
        SurfaceCard(title: "训练概览", subtitle: "只统计当前保留的阅读与支撑模块。") {
            HStack(spacing: 12) {
                MetricTile(label: "总训练", value: "\(appModel.statistics.totalSessions)", accent: BDColor.primaryBlue)
                MetricTile(label: "阅读训练", value: "\(appModel.statistics.readingSessionCount)", accent: BDColor.gold)
                MetricTile(label: "支撑训练", value: "\(appModel.statistics.supportSessionCount)", accent: BDColor.teal)
                MetricTile(label: "最近主线", value: appModel.statistics.lastReadingModuleName ?? "--", accent: BDColor.green)
            }
        }
    }

    private var recommendedCard: some View {
        let recs = TrainingScheduler.recommend(
            sessions: appModel.sessions.filter { TrainingModule.allCases.contains($0.module) },
            allModules: TrainingModule.allCases,
            maxCount: 4
        )

        return SurfaceCard(title: "今日建议", subtitle: "优先补主线阅读训练，再用支撑模块兜底。") {
            if recs.isEmpty {
                Text("开始你的第一次训练吧。")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(recs) { rec in
                        Button {
                            if let route = route(for: rec.module) {
                                appModel.selectedRoute = route
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: rec.module.systemImage)
                                    .foregroundStyle(moduleColor(rec.module))
                                    .frame(width: 22)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(rec.module.displayName)
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundStyle(BDColor.textPrimary)
                                    Text(rec.reason)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(BDColor.textSecondary)
                                }
                                Spacer()
                                InfoPill(title: priorityLabel(rec.priority), accent: moduleColor(rec.module))
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(BDColor.historyRow))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var activeModulesCard: some View {
        SurfaceCard(title: "当前模块", subtitle: "阅读 3 项 + 支撑 3 项。") {
            VStack(alignment: .leading, spacing: 16) {
                moduleGroup(title: "阅读训练", modules: [.mainIdea, .evidenceMap, .delayedRecall])
                moduleGroup(title: "支撑训练", modules: [.schulte, .visualSearch, .nBack])
            }
        }
    }

    private func moduleGroup(title: String, modules: [TrainingModule]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(BDColor.textSecondary)

            ForEach(modules) { module in
                Button {
                    if let route = route(for: module) {
                        appModel.selectedRoute = route
                    }
                } label: {
                    HStack {
                        Image(systemName: module.systemImage)
                            .foregroundStyle(moduleColor(module))
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(module.displayName)
                                .font(.system(.callout, design: .rounded, weight: .medium))
                                .foregroundStyle(BDColor.textPrimary)
                            Text(module.subtitle)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(BDColor.textSecondary)
                        }
                        Spacer()
                        Text("\(appModel.statistics.count(for: module)) 次")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(BDColor.textSecondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(BDColor.panelSecondaryFill.opacity(0.26)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func route(for module: TrainingModule) -> AppRoute? {
        AppRoute.readingModules
            .first(where: { $0.trainingModule == module })
            ?? AppRoute.supportModules.first(where: { $0.trainingModule == module })
    }

    private func moduleColor(_ module: TrainingModule) -> Color {
        switch module {
        case .mainIdea:      BDColor.gold
        case .evidenceMap:   BDColor.teal
        case .delayedRecall: BDColor.green
        case .schulte:       BDColor.primaryBlue
        case .visualSearch:  BDColor.visualSearchAccent
        case .nBack:         BDColor.nBackAccent
        default:             BDColor.textSecondary
        }
    }

    private func priorityLabel(_ priority: Double) -> String {
        if priority >= 80 { return "优先" }
        if priority >= 50 { return "建议" }
        return "可选"
    }
}
