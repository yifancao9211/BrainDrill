import SwiftUI

struct DailyPlanView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showAllModules = false

    var body: some View {
        VStack(spacing: 24) {
            recommendedCard
            if showAllModules { allModulesCard }
            if appModel.statistics.totalSessions > 0 { overviewCard }
        }
    }

    private var recommendedCard: some View {
        let recs = TrainingScheduler.recommend(
            sessions: appModel.sessions,
            allModules: TrainingModule.allCases,
            maxCount: 4
        )

        return SurfaceCard(title: "今日推荐", subtitle: "基于你的训练频率和表现趋势，推荐以下模块") {
            VStack(spacing: 12) {
                if recs.isEmpty {
                    Text("开始你的第一次训练吧！")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    ForEach(recs) { rec in
                        Button {
                            if let route = AppRoute.allCases.first(where: { $0.trainingModule == rec.module }) {
                                withAnimation(.snappy(duration: 0.25)) {
                                    appModel.selectedRoute = route
                                }
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: rec.module.systemImage)
                                    .font(.system(.title3, weight: .semibold))
                                    .foregroundStyle(moduleColor(rec.module))
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(moduleColor(rec.module).opacity(0.12)))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(rec.module.displayName)
                                        .font(.system(.headline, design: .rounded))
                                    Text(rec.reason)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                priorityBadge(rec.priority)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(14)
                            .contentShape(Rectangle())
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(BDColor.historyRow)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        showAllModules.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(showAllModules ? "收起全部模块" : "查看全部 \(TrainingModule.allCases.count) 个模块")
                        Image(systemName: showAllModules ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var allModulesCard: some View {
        SurfaceCard(title: "全部模块") {
            let grouped = Dictionary(grouping: TrainingModule.allCases) { $0.dimension }
            VStack(alignment: .leading, spacing: 16) {
                ForEach(TrainingModule.Dimension.allCases) { dim in
                    if let modules = grouped[dim] {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(dim.displayName)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)

                            ForEach(modules) { mod in
                                Button {
                                    if let route = AppRoute.allCases.first(where: { $0.trainingModule == mod }) {
                                        withAnimation(.snappy(duration: 0.25)) {
                                            appModel.selectedRoute = route
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: mod.systemImage)
                                            .foregroundStyle(moduleColor(mod))
                                            .frame(width: 20)
                                        Text(mod.displayName)
                                            .font(.system(.callout, design: .rounded))
                                        Spacer()
                                        let count = appModel.statistics.count(for: mod)
                                        if count > 0 {
                                            Text("\(count)次")
                                                .font(.system(.caption2, design: .rounded))
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var overviewCard: some View {
        SurfaceCard(title: "训练概览") {
            HStack(spacing: 16) {
                MetricTile(label: "总训练", value: "\(appModel.statistics.totalSessions)", accent: BDColor.primaryBlue)
                MetricTile(label: "舒尔特最佳", value: appModel.statistics.bestSchulteTime.map(appModel.formattedDuration) ?? "--", accent: BDColor.gold)
                if let n = appModel.statistics.bestNBackLevel {
                    MetricTile(label: "最高N-Back", value: "\(n)-Back", accent: BDColor.nBackAccent)
                }
            }
        }
    }

    private func priorityBadge(_ priority: Double) -> some View {
        let color: Color = priority >= 80 ? BDColor.error : (priority >= 50 ? BDColor.gold : BDColor.green)
        let label = priority >= 80 ? "急需" : (priority >= 50 ? "推荐" : "可选")
        return Text(label)
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.1)))
    }

    private func moduleColor(_ module: TrainingModule) -> Color {
        switch module {
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
        }
    }
}
