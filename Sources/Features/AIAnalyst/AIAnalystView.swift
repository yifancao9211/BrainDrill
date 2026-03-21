import SwiftUI

struct AIAnalystView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 24) {
            radarCard
            insightsCard
            recommendationsCard
            timeOfDayCard
            exportCard
        }
    }

    // MARK: - Cognitive Radar

    private var radarCard: some View {
        SurfaceCard(title: "认知画像", subtitle: "五维能力雷达图") {
            let profile = appModel.cognitiveProfile
            if profile.dimensions.allSatisfy({ $0.score == 0 }) {
                Text("完成至少一次训练后显示认知画像")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 16) {
                    RadarChartView(dimensions: profile.dimensions)
                        .frame(height: 240)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(profile.dimensions) { dim in
                            VStack(spacing: 4) {
                                Text(dim.name)
                                    .font(.system(.caption2, design: .rounded, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.0f", dim.score))
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundStyle(scoreColor(dim.score))
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(scoreColor(dim.score).opacity(0.08)))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Insights

    private var insightsCard: some View {
        let insights = PerformanceInsightExtractor.extract(from: appModel.sessions)
        return SurfaceCard(title: "表现洞察", subtitle: "趋势分析") {
            if insights.isEmpty {
                Text("需要更多训练数据才能生成洞察")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(insights) { insight in
                        HStack(spacing: 10) {
                            Image(systemName: insightIcon(insight.type))
                                .foregroundStyle(insightColor(insight.type))
                                .frame(width: 20)
                            Text(insight.message)
                                .font(.system(.callout, design: .rounded))
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(insightColor(insight.type).opacity(0.06)))
                    }
                }
            }
        }
    }

    // MARK: - Recommendations

    private var recommendationsCard: some View {
        let recs = TrainingScheduler.recommend(sessions: appModel.sessions, allModules: TrainingModule.allCases, maxCount: 4)
        return SurfaceCard(title: "今日推荐", subtitle: "基于训练频率与表现趋势") {
            VStack(spacing: 8) {
                ForEach(recs) { rec in
                    Button {
                        if let route = AppRoute.allCases.first(where: { $0.trainingModule == rec.module }) {
                            withAnimation(.snappy(duration: 0.25)) {
                                appModel.selectedRoute = route
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: rec.module.systemImage)
                                .foregroundStyle(BDColor.teal)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rec.module.displayName)
                                    .font(.system(.callout, design: .rounded, weight: .medium))
                                Text(rec.reason)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(String(format: "%.0f", rec.priority))
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(BDColor.teal)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Capsule().fill(BDColor.teal.opacity(0.1)))
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(BDColor.historyRow))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Time of Day

    private var timeOfDayCard: some View {
        let analysis = TimeOfDayAnalyzer.analyze(sessions: appModel.sessions)
        return SurfaceCard(title: "时段表现", subtitle: "找到你的最佳训练时段") {
            if analysis.slots.isEmpty {
                Text("需要在不同时段训练后显示分析")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 8) {
                    ForEach(analysis.slots) { slot in
                        HStack {
                            Text(slot.name)
                                .font(.system(.callout, design: .rounded, weight: .medium))
                                .frame(width: 40, alignment: .leading)
                            GeometryReader { geo in
                                let maxScore = analysis.slots.map(\.averageScore).max() ?? 1
                                let w = max(30, geo.size.width * CGFloat(slot.averageScore / maxScore))
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(BDColor.barTrack)
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(slot.id == analysis.bestSlot?.id ? BDColor.teal : BDColor.primaryBlue.opacity(0.5))
                                        .frame(width: w)
                                }
                            }
                            .frame(height: 16)
                            Text("\(slot.sessionCount)次")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }

                    if let best = analysis.bestSlot {
                        Text("最佳训练时段：\(best.name)（\(best.hourRange.lowerBound):00-\(best.hourRange.upperBound + 1):00）")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(BDColor.teal)
                            .padding(.top, 4)
                    }
                }
            }
        }
    }

    // MARK: - Export

    private var exportCard: some View {
        SurfaceCard(title: "数据导出") {
            HStack(spacing: 12) {
                Button {
                    let csv = appModel.exportSessionsCSV()
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(csv, forType: .string)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard")
                        Text("复制 CSV 到剪贴板")
                    }
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(BDColor.primaryBlue.opacity(0.12)))
                    .foregroundStyle(BDColor.primaryBlue)
                }
                .buttonStyle(.plain)

                Text("\(appModel.sessions.count) 条记录")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Double) -> Color {
        if score >= 70 { return BDColor.green }
        if score >= 40 { return BDColor.gold }
        return BDColor.error
    }

    private func insightIcon(_ type: InsightType) -> String {
        switch type {
        case .improving: "arrow.up.circle.fill"
        case .declining: "arrow.down.circle.fill"
        case .plateau:   "arrow.right.circle.fill"
        case .newBest:   "star.circle.fill"
        case .anomaly:   "exclamationmark.triangle.fill"
        }
    }

    private func insightColor(_ type: InsightType) -> Color {
        switch type {
        case .improving: BDColor.green
        case .declining: BDColor.error
        case .plateau:   BDColor.gold
        case .newBest:   BDColor.primaryBlue
        case .anomaly:   BDColor.error
        }
    }
}

// MARK: - Radar Chart

private struct RadarChartView: View {
    let dimensions: [CognitiveDimension]

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 - 30
            let count = dimensions.count
            let angleStep = 2 * .pi / Double(count)

            ZStack {
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                    radarPolygon(center: center, radius: radius * level, count: count, angleStep: angleStep)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }

                ForEach(0..<count, id: \.self) { i in
                    let angle = angleStep * Double(i) - .pi / 2
                    let end = CGPoint(
                        x: center.x + radius * cos(angle),
                        y: center.y + radius * sin(angle)
                    )
                    Path { p in
                        p.move(to: center)
                        p.addLine(to: end)
                    }
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)

                    Text(dimensions[i].name)
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                        .position(
                            x: center.x + (radius + 20) * cos(angle),
                            y: center.y + (radius + 20) * sin(angle)
                        )
                }

                radarDataPolygon(center: center, radius: radius, count: count, angleStep: angleStep)
                    .fill(BDColor.teal.opacity(0.15))
                radarDataPolygon(center: center, radius: radius, count: count, angleStep: angleStep)
                    .stroke(BDColor.teal, lineWidth: 2)

                ForEach(0..<count, id: \.self) { i in
                    let score = dimensions[i].score / 100.0
                    let angle = angleStep * Double(i) - .pi / 2
                    Circle()
                        .fill(BDColor.teal)
                        .frame(width: 6, height: 6)
                        .position(
                            x: center.x + radius * score * cos(angle),
                            y: center.y + radius * score * sin(angle)
                        )
                }
            }
        }
    }

    private func radarPolygon(center: CGPoint, radius: Double, count: Int, angleStep: Double) -> Path {
        Path { path in
            for i in 0..<count {
                let angle = angleStep * Double(i) - .pi / 2
                let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
        }
    }

    private func radarDataPolygon(center: CGPoint, radius: Double, count: Int, angleStep: Double) -> Path {
        Path { path in
            for i in 0..<count {
                let score = dimensions[i].score / 100.0
                let angle = angleStep * Double(i) - .pi / 2
                let point = CGPoint(x: center.x + radius * score * cos(angle), y: center.y + radius * score * sin(angle))
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
        }
    }
}
