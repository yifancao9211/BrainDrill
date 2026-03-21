import SwiftUI

struct DailyPlanView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 24) {
            SurfaceCard(title: "今日训练计划", subtitle: "建议每日 20 分钟，每周 3-5 次。") {
                VStack(spacing: 16) {
                    ForEach(dailyModules, id: \.route) { item in
                        Button {
                            withAnimation(.snappy(duration: 0.25)) {
                                appModel.selectedRoute = item.route
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: item.route.systemImage)
                                    .font(.system(.title3, weight: .semibold))
                                    .foregroundStyle(item.color)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(item.color.opacity(0.12)))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.route.title)
                                        .font(.system(.headline, design: .rounded))
                                    Text(item.subtitle)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(item.duration)
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundStyle(.secondary)
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
            }

            if appModel.statistics.totalSessions > 0 {
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
        }
    }

    private struct DailyItem {
        let route: AppRoute
        let subtitle: String
        let duration: String
        let color: Color
    }

    private var dailyModules: [DailyItem] {
        [
            DailyItem(route: .digitSpan, subtitle: "短时记忆与工作记忆", duration: "~3 min", color: BDColor.digitSpanAccent),
            DailyItem(route: .corsiBlock, subtitle: "视觉空间工作记忆", duration: "~3 min", color: BDColor.corsiBlockAccent),
            DailyItem(route: .nBack, subtitle: "工作记忆更新", duration: "~5 min", color: BDColor.nBackAccent),
            DailyItem(route: .changeDetection, subtitle: "视觉工作记忆", duration: "~4 min", color: BDColor.changeDetectionAccent),
            DailyItem(route: .choiceRT, subtitle: "感知-决策-反应速度", duration: "~3 min", color: BDColor.choiceRTAccent),
            DailyItem(route: .goNoGo, subtitle: "反应抑制 · 冲动控制", duration: "~3 min", color: BDColor.goNoGoAccent),
            DailyItem(route: .flanker, subtitle: "选择性注意力 · 抑制控制", duration: "~4 min", color: BDColor.flankerAccent),
            DailyItem(route: .stopSignal, subtitle: "动作抑制与停止控制", duration: "~4 min", color: BDColor.stopSignalAccent),
            DailyItem(route: .schulte, subtitle: "视觉注意力训练", duration: "~8 min", color: BDColor.primaryBlue),
            DailyItem(route: .visualSearch, subtitle: "选择性注意与搜索效率", duration: "~5 min", color: BDColor.visualSearchAccent),
        ]
    }
}
