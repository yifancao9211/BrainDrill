import SwiftUI

struct StatisticsView: View {
    @Environment(AppModel.self) private var appModel

    private var stats: TrainingStatistics { appModel.statistics }

    var body: some View {
        VStack(spacing: 24) {
            overviewCard
            if stats.schulteCount > 0 { schulteCard }
            if stats.flankerCount > 0 { flankerCard }
            if stats.goNoGoCount > 0 { goNoGoCard }
            if stats.nBackCount > 0 { nBackCard }
            if stats.digitSpanCount > 0 { digitSpanCard }
            if stats.choiceRTCount > 0 { choiceRTCard }
            if stats.changeDetectionCount > 0 { changeDetectionCard }
            if stats.visualSearchCount > 0 { visualSearchCard }
        }
    }

    private var overviewCard: some View {
        SurfaceCard(title: "综合统计") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                MetricTile(label: "总训练", value: "\(stats.totalSessions)", accent: BDColor.primaryBlue)
                ForEach(TrainingModule.allCases) { module in
                    let count = stats.count(for: module)
                    if count > 0 {
                        MetricTile(label: module.shortName, value: "\(count)", accent: accentColor(for: module))
                    }
                }
            }
        }
    }

    private var schulteCard: some View {
        SurfaceCard(title: "舒尔特方格", subtitle: "视觉注意力训练") {
            HStack(spacing: 16) {
                MetricTile(label: "最佳用时", value: stats.bestSchulteTime.map(appModel.formattedDuration) ?? "--", accent: BDColor.gold)
                MetricTile(label: "近5次均值", value: stats.recentSchulteAverage.map(appModel.formattedDuration) ?? "--", accent: BDColor.green)
                MetricTile(label: "常用难度", value: stats.mostPlayedDifficulty?.shortLabel ?? "--", accent: BDColor.warm)
            }

            if !stats.recentSchulteTrend.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(stats.recentSchulteTrend) { point in
                        HStack {
                            Text(point.difficulty.shortLabel)
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .leading)
                            GeometryReader { proxy in
                                let maxD = stats.recentSchulteTrend.map(\.duration).max() ?? 1
                                let w = max(40, proxy.size.width * CGFloat(point.duration / maxD))
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(BDColor.barTrack)
                                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(BDGradient.primaryBlue).frame(width: w)
                                }
                            }
                            .frame(height: 14)
                            Text(appModel.formattedDuration(point.duration))
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private var flankerCard: some View {
        SurfaceCard(title: "Flanker 反应力", subtitle: "选择性注意力训练") {
            HStack(spacing: 16) {
                MetricTile(label: "最佳冲突代价", value: stats.bestFlankerConflictCost.map { "\(Int($0 * 1000))ms" } ?? "--", accent: BDColor.flankerAccent)
            }
        }
    }

    private var goNoGoCard: some View {
        SurfaceCard(title: "Go/No-Go 抑制力", subtitle: "反应抑制训练") {
            HStack(spacing: 16) {
                MetricTile(label: "最佳 d'", value: stats.bestGoNoGoDPrime.map { String(format: "%.2f", $0) } ?? "--", accent: BDColor.goNoGoAccent)
            }
        }
    }

    private var nBackCard: some View {
        SurfaceCard(title: "N-Back 记忆", subtitle: "工作记忆训练") {
            HStack(spacing: 16) {
                MetricTile(label: "最高级别", value: stats.bestNBackLevel.map { "\($0)-Back" } ?? "--", accent: BDColor.nBackAccent)
            }
        }
    }

    private var digitSpanCard: some View {
        SurfaceCard(title: "数字广度", subtitle: "短时记忆与工作记忆") {
            HStack(spacing: 16) {
                MetricTile(label: "最大广度", value: stats.bestDigitSpan.map { "\($0)" } ?? "--", accent: BDColor.digitSpanAccent)
            }
        }
    }

    private var choiceRTCard: some View {
        SurfaceCard(title: "选择反应时", subtitle: "感知-决策-反应速度") {
            HStack(spacing: 16) {
                MetricTile(label: "最佳中位RT", value: stats.bestChoiceRTMedian.map { "\(Int($0 * 1000))ms" } ?? "--", accent: BDColor.choiceRTAccent)
            }
        }
    }

    private var changeDetectionCard: some View {
        SurfaceCard(title: "变更检测", subtitle: "视觉工作记忆") {
            HStack(spacing: 16) {
                MetricTile(label: "最佳 d'", value: stats.bestChangeDetectionDPrime.map { String(format: "%.2f", $0) } ?? "--", accent: BDColor.changeDetectionAccent)
            }
        }
    }

    private var visualSearchCard: some View {
        SurfaceCard(title: "视觉搜索", subtitle: "选择性注意与搜索效率") {
            HStack(spacing: 16) {
                MetricTile(label: "最佳搜索斜率", value: stats.bestVisualSearchSlope.map { "\(Int($0 * 1000))ms/项" } ?? "--", accent: BDColor.visualSearchAccent)
            }
        }
    }

    private func accentColor(for module: TrainingModule) -> Color {
        switch module {
        case .schulte:         BDColor.primaryBlue
        case .flanker:         BDColor.flankerAccent
        case .goNoGo:          BDColor.goNoGoAccent
        case .nBack:           BDColor.nBackAccent
        case .digitSpan:       BDColor.digitSpanAccent
        case .choiceRT:        BDColor.choiceRTAccent
        case .changeDetection: BDColor.changeDetectionAccent
        case .visualSearch:    BDColor.visualSearchAccent
        }
    }
}
