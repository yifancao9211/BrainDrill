import SwiftUI

struct StatisticsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 24) {
            metricsCard
            trendCard
        }
    }

    private var metricsCard: some View {
        SurfaceCard(title: "统计面板", subtitle: "核心指标会随着每轮训练自动更新。") {
            HStack(spacing: 16) {
                MetricTile(
                    label: "总训练次数",
                    value: "\(appModel.statistics.totalSessions)",
                    accent: Color(red: 0.17, green: 0.41, blue: 0.72)
                )
                MetricTile(
                    label: "个人最佳",
                    value: appModel.statistics.bestTime.map(appModel.formattedDuration) ?? "--",
                    accent: Color(red: 0.75, green: 0.56, blue: 0.18)
                )
                MetricTile(
                    label: "近 5 次均值",
                    value: appModel.statistics.recentAverage.map(appModel.formattedDuration) ?? "--",
                    accent: Color(red: 0.16, green: 0.52, blue: 0.42)
                )
                MetricTile(
                    label: "常用难度",
                    value: appModel.statistics.mostPlayedDifficulty?.shortLabel ?? "--",
                    accent: Color(red: 0.51, green: 0.34, blue: 0.12)
                )
            }
        }
    }

    private var trendCard: some View {
        SurfaceCard(title: "近期趋势", subtitle: "最近 7 轮的表现会压缩成节奏条，越短表示越快。") {
            if appModel.statistics.recentTrend.isEmpty {
                ContentUnavailableView(
                    "暂无趋势数据",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("完成一轮训练后，这里会开始显示近期表现。")
                )
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    if let improvement = appModel.statistics.recentImprovement {
                        Text(
                            improvement <= 0
                                ? "最近一轮比前几轮平均快 \(appModel.formattedDuration(abs(improvement)))。"
                                : "最近一轮比前几轮平均慢 \(appModel.formattedDuration(improvement))。"
                        )
                        .font(.system(.headline, design: .rounded))
                    }

                    ForEach(appModel.statistics.recentTrend) { point in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("第 \(point.index) 条")
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(point.difficulty.shortLabel)
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text(appModel.formattedDuration(point.duration))
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                            }

                            GeometryReader { proxy in
                                let maxDuration = appModel.statistics.recentTrend.map(\.duration).max() ?? 1
                                let width = max(48, proxy.size.width * CGFloat(point.duration / maxDuration))

                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.black.opacity(0.05))
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(red: 0.17, green: 0.41, blue: 0.72), Color(red: 0.38, green: 0.58, blue: 0.82)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: width)
                                }
                            }
                            .frame(height: 16)
                        }
                    }
                }
            }
        }
    }
}
