import SwiftUI

struct TrainingView: View {
    @Environment(AppModel.self) private var appModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            hero
            configurationCard
            if let engine = appModel.activeEngine {
                activeSessionCard(engine: engine)
            }
            if let summary = appModel.lastCompletedSummary {
                completionCard(summary: summary)
            }
            if let error = appModel.lastPersistenceError {
                SurfaceCard(title: "持久化提示") {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var hero: some View {
        SurfaceCard(title: "舒尔特方格训练", subtitle: "用更稳定的节奏扫描数字，拉起专注与视觉搜索能力。") {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(appModel.statusMessage)
                        .font(.system(.title3, design: .rounded, weight: .medium))
                    HStack(spacing: 10) {
                        InfoPill(title: "本地记录", accent: Color(red: 0.17, green: 0.41, blue: 0.72))
                        InfoPill(title: "中文优先", accent: Color(red: 0.51, green: 0.34, blue: 0.12))
                        InfoPill(title: "首版专注舒尔特", accent: Color(red: 0.12, green: 0.48, blue: 0.39))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Text("今日节奏")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(appModel.statistics.latestTime.map(appModel.formattedDuration) ?? "未开始")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                }
            }
        }
    }

    private var configurationCard: some View {
        SurfaceCard(title: "训练配置", subtitle: "难度和提示会作为你的默认设置保存到本机。") {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("难度")
                        .font(.system(.headline, design: .rounded))

                    HStack(spacing: 12) {
                        ForEach(SchulteDifficulty.allCases) { difficulty in
                            difficultyButton(difficulty)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 14) {
                    Toggle(
                        "高亮当前目标数字",
                        isOn: Binding(
                            get: { appModel.settings.showHints },
                            set: { appModel.updateShowHints($0) }
                        )
                    )
                    Toggle(
                        "启用音效反馈（预留设置）",
                        isOn: Binding(
                            get: { appModel.settings.enableSoundFeedback },
                            set: { appModel.updateSoundFeedback($0) }
                        )
                    )
                    .toggleStyle(.switch)
                }
                .frame(maxWidth: 280, alignment: .leading)
            }

            HStack(spacing: 12) {
                Button(appModel.isTrainingActive ? "重新开始" : "开始训练") {
                    appModel.startSession()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if appModel.isTrainingActive {
                    Button("取消本轮") {
                        appModel.cancelSession()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
    }

    private func activeSessionCard(engine: SchulteEngine) -> some View {
        SurfaceCard(title: "当前训练", subtitle: "目标数字会随着正确点击自动推进。") {
            HStack(spacing: 16) {
                MetricTile(label: "目标数字", value: "\(engine.nextExpectedNumber)", accent: Color(red: 0.14, green: 0.43, blue: 0.75))
                MetricTile(label: "错误次数", value: "\(engine.mistakeCount)", accent: Color(red: 0.72, green: 0.34, blue: 0.25))
                TimelineView(.periodic(from: .now, by: 0.1)) { context in
                    MetricTile(label: "已用时间", value: appModel.elapsedTimeString(at: context.date), accent: Color(red: 0.16, green: 0.52, blue: 0.42))
                }
            }

            ProgressView(value: engine.completionFraction)
                .tint(Color(red: 0.17, green: 0.41, blue: 0.72))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: engine.config.difficulty.gridSize), spacing: 12) {
                ForEach(engine.tiles) { tile in
                    Button {
                        appModel.handleTileTap(tile.number)
                    } label: {
                        VStack(spacing: 6) {
                            Text("\(tile.number)")
                                .font(.system(size: CGFloat(engine.config.difficulty.gridSize == 5 ? 22 : 28), weight: .bold, design: .rounded))
                            if engine.config.showHints && tile.number == engine.nextExpectedNumber {
                                Text("当前")
                                    .font(.system(.caption2, design: .rounded, weight: .bold))
                            }
                        }
                        .foregroundStyle(tileForegroundColor(tile.number, engine: engine))
                        .frame(maxWidth: .infinity, minHeight: tileHeight(for: engine.config.difficulty))
                        .background(tileBackground(tile.number, engine: engine))
                    }
                    .buttonStyle(.plain)
                    .disabled(engine.completedNumbers.contains(tile.number))
                    .accessibilityLabel("数字 \(tile.number)")
                    .accessibilityHint(tile.number == engine.nextExpectedNumber ? "当前目标数字" : "点击以继续训练")
                }
            }
        }
    }

    private func completionCard(summary: CompletedSessionSummary) -> some View {
        SurfaceCard(title: "本轮结果", subtitle: "刚完成的一轮训练已经写入本地记录。") {
            HStack(spacing: 16) {
                MetricTile(label: "总耗时", value: appModel.formattedDuration(summary.result.duration), accent: Color(red: 0.17, green: 0.41, blue: 0.72))
                MetricTile(label: "错误次数", value: "\(summary.result.mistakeCount)", accent: Color(red: 0.72, green: 0.34, blue: 0.25))
                MetricTile(label: "训练难度", value: summary.result.difficulty.shortLabel, accent: Color(red: 0.16, green: 0.52, blue: 0.42))
            }

            HStack(spacing: 12) {
                if summary.didSetPersonalBest {
                    InfoPill(title: "个人最佳", accent: Color(red: 0.75, green: 0.56, blue: 0.18))
                }
                if let delta = summary.trendDelta {
                    InfoPill(
                        title: delta <= 0 ? "比近期均值快 \(appModel.formattedDuration(abs(delta)))" : "比近期均值慢 \(appModel.formattedDuration(delta))",
                        accent: delta <= 0 ? Color(red: 0.16, green: 0.52, blue: 0.42) : Color(red: 0.72, green: 0.34, blue: 0.25)
                    )
                }
                InfoPill(title: appModel.formattedDate(summary.result.endedAt), accent: Color.secondary)
            }
        }
    }

    private func difficultyButton(_ difficulty: SchulteDifficulty) -> some View {
        Button {
            appModel.updatePreferredDifficulty(difficulty)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(difficulty.displayName)
                    .font(.system(.headline, design: .rounded))
                Text(difficulty.description)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("\(difficulty.totalTiles) 个数字")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(appModel.settings.preferredDifficulty == difficulty ? Color(red: 0.17, green: 0.41, blue: 0.72).opacity(0.16) : Color.white.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(appModel.settings.preferredDifficulty == difficulty ? Color(red: 0.17, green: 0.41, blue: 0.72) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .frame(width: 180)
    }

    private func tileHeight(for difficulty: SchulteDifficulty) -> CGFloat {
        switch difficulty {
        case .easy3x3:
            112
        case .focus4x4:
            88
        case .challenge5x5:
            72
        }
    }

    private func tileBackground(_ number: Int, engine: SchulteEngine) -> some ShapeStyle {
        if engine.completedNumbers.contains(number) {
            return AnyShapeStyle(Color(red: 0.82, green: 0.88, blue: 0.84))
        }
        if engine.config.showHints && number == engine.nextExpectedNumber {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(red: 0.17, green: 0.41, blue: 0.72), Color(red: 0.38, green: 0.58, blue: 0.82)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(Color.white.opacity(0.78))
    }

    private func tileForegroundColor(_ number: Int, engine: SchulteEngine) -> Color {
        if engine.completedNumbers.contains(number) {
            return Color(red: 0.33, green: 0.42, blue: 0.35)
        }
        if engine.config.showHints && number == engine.nextExpectedNumber {
            return .white
        }
        return Color.primary
    }
}
