import SwiftUI

struct SchulteTrainingView: View {
    @Environment(AppModel.self) private var appModel

    private var coordinator: SchulteCoordinator { appModel.schulte }

    var body: some View {
        ZStack {
            if let engine = coordinator.activeEngine {
                activeSessionView(engine: engine)
                    .transition(.opacity)
            } else if coordinator.isResting {
                restView
                    .transition(.opacity)
            } else {
                idleView
                    .transition(.opacity)
            }

            if let summary = coordinator.lastCompletedSummary {
                SchulteResultOverlay(summary: summary)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.3), value: coordinator.isTrainingActive)
        .animation(.snappy(duration: 0.35), value: coordinator.lastCompletedSummary != nil)
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(BDColor.primaryBlue.opacity(0.6))

                Text("舒尔特方格训练")
                    .font(.system(.title2, design: .rounded, weight: .semibold))

                Text("当前难度：\(appModel.settings.preferredDifficulty.displayName)")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)

                if appModel.settings.showFixationDot {
                    HStack(spacing: 6) {
                        Circle().fill(.red).frame(width: 8, height: 8)
                        Text("中心凝视点已开启 — 目光锁定中心，用周边视觉找数字")
                    }
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                }

                let cfg = appModel.settings.schulteSetRep
                Text("\(cfg.setsPerSession)组 × \(cfg.repsPerSet)次/组")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)

                if appModel.settings.adaptiveDifficultyEnabled {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("自动升级已开启")
                    }
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.gold)
                }
            }

            Button {
                appModel.startSchulteSession()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("开始训练")
                }
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(Capsule(style: .continuous).fill(BDGradient.primaryBlue))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Rest

    private var restView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("休息中")
                .font(.system(.title2, design: .rounded, weight: .semibold))

            Text("\(coordinator.restCountdown)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(BDColor.primaryBlue)
                .monospacedDigit()

            Text("第\(coordinator.currentSet + 1)组 第\(coordinator.currentRep + 1)次 即将开始")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)

            Button("跳过休息") {
                coordinator.skipRest(settings: appModel.settings)
            }
            .font(.system(.callout, design: .rounded, weight: .medium))
            .buttonStyle(.bordered)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Active Session

    private func activeSessionView(engine: SchulteEngine) -> some View {
        VStack(spacing: 0) {
            sessionStatusBar(engine: engine)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 6)

            Spacer(minLength: 8)

            ZStack {
                gridView(engine: engine)
                if engine.config.showFixationDot {
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 8)

            sessionBottomBar(engine: engine)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sessionStatusBar(engine: SchulteEngine) -> some View {
        HStack(spacing: 12) {
            Label {
                Text(coordinator.statusMessage)
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .lineLimit(1)
            } icon: {
                Image(systemName: "target")
                    .foregroundStyle(BDColor.primaryBlue)
            }

            Spacer()

            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                Text(coordinator.elapsedTimeString(at: context.date))
                    .font(.system(.title3, design: .monospaced, weight: .semibold))
                    .foregroundStyle(BDColor.green)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(BDColor.cardStroke, lineWidth: 1))
        )
    }

    private func gridView(engine: SchulteEngine) -> some View {
        let gridSize = engine.config.difficulty.gridSize
        let maxSide: CGFloat = switch gridSize {
        case 3: 380; case 4: 440; case 5: 500; case 6: 540
        case 7: 580; case 8: 620; default: 660
        }
        let spacing: CGFloat = gridSize <= 5 ? 6 : (gridSize <= 7 ? 4 : 3)

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: gridSize),
            spacing: spacing
        ) {
            ForEach(engine.tiles) { tile in
                SchulteTileButton(tile: tile, engine: engine) {
                    appModel.handleSchulteTileTap(tile.number)
                }
            }
        }
        .frame(maxWidth: maxSide)
    }

    private func sessionBottomBar(engine: SchulteEngine) -> some View {
        HStack {
            HStack(spacing: 12) {
                MiniStat(label: "目标", value: "\(engine.nextExpectedNumber)/\(engine.totalTiles)", color: BDColor.primaryBlue)
                MiniStat(label: "错误", value: "\(engine.mistakeCount)", color: BDColor.error)
                MiniStat(label: "进度", value: "\(coordinator.completedReps + 1)/\(coordinator.totalRepsInSession)", color: BDColor.warm)
            }

            Spacer()

            ProgressView(value: engine.completionFraction)
                .tint(BDColor.primaryBlue)
                .frame(maxWidth: 140)
                .animation(.easeInOut(duration: 0.15), value: engine.completionFraction)

            Spacer()

            Button("取消") { appModel.cancelSchulteSession() }
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(BDColor.error)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(BDColor.cardStroke, lineWidth: 1))
        )
    }
}

// MARK: - Mini Stat

private struct MiniStat: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.system(.caption2, design: .rounded)).foregroundStyle(.secondary)
            Text(value).font(.system(.caption, design: .rounded, weight: .semibold)).foregroundStyle(color).monospacedDigit()
        }
    }
}

// MARK: - Tile Button

private struct SchulteTileButton: View {
    let tile: SchulteTile
    let engine: SchulteEngine
    let onTap: () -> Void

    @State private var isPressed = false
    @State private var showCorrect = false

    private var isCompleted: Bool { engine.completedNumbers.contains(tile.number) }
    private var isTarget: Bool { engine.config.showHints && tile.number == engine.nextExpectedNumber }
    private var distractionColorIndex: Int? { engine.distractionMap[tile.number] }

    var body: some View {
        Button {
            guard !isCompleted else { return }
            if tile.number == engine.nextExpectedNumber {
                withAnimation(.spring(duration: 0.25, bounce: 0.4)) { showCorrect = true }
            }
            onTap()
        } label: {
            Text("\(tile.number)")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(background)
                .scaleEffect(isPressed ? 0.90 : (showCorrect ? 1.06 : 1.0))
        }
        .buttonStyle(TilePressStyle(isPressed: $isPressed))
        .disabled(isCompleted)
        .onChange(of: showCorrect) { _, val in
            if val {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeOut(duration: 0.15)) { showCorrect = false }
                }
            }
        }
    }

    private var fontSize: CGFloat {
        switch engine.config.difficulty.gridSize {
        case 3: 32; case 4: 26; case 5: 20; case 6: 17; case 7: 14; case 8: 12; default: 10
        }
    }

    @ViewBuilder
    private var background: some View {
        let r: CGFloat = engine.config.difficulty.gridSize <= 5 ? 12 : (engine.config.difficulty.gridSize <= 7 ? 8 : 6)
        if isCompleted {
            RoundedRectangle(cornerRadius: r, style: .continuous).fill(BDColor.tileCompleted)
        } else if isTarget {
            RoundedRectangle(cornerRadius: r, style: .continuous).fill(BDGradient.primaryBlue).shadow(color: BDColor.primaryBlue.opacity(0.3), radius: 6, y: 2)
        } else if let idx = distractionColorIndex {
            RoundedRectangle(cornerRadius: r, style: .continuous).fill(BDColor.distractionColors[idx].opacity(0.25))
                .overlay(RoundedRectangle(cornerRadius: r, style: .continuous).stroke(BDColor.distractionColors[idx].opacity(0.4), lineWidth: 1.5))
        } else {
            RoundedRectangle(cornerRadius: r, style: .continuous).fill(BDColor.tileDefault)
        }
    }

    private var foregroundColor: Color {
        if isCompleted { return BDColor.tileCompletedText }
        if isTarget { return .white }
        if let idx = distractionColorIndex { return BDColor.distractionColors[idx] }
        return .primary
    }
}

private struct TilePressStyle: ButtonStyle {
    @Binding var isPressed: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, p in isPressed = p }
    }
}

// MARK: - Result Overlay

private struct SchulteResultOverlay: View {
    @Environment(AppModel.self) private var appModel
    let summary: CompletedSchulteSummary
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.35 : 0).ignoresSafeArea().onTapGesture { dismiss() }
            VStack(spacing: 20) {
                if summary.didSetPersonalBest {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                        Text("新纪录！")
                    }
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(BDColor.gold)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Capsule().fill(BDColor.gold.opacity(0.12)))
                }

                Text("第\(summary.setIndex + 1)组 第\(summary.repIndex + 1)次 完成")
                    .font(.system(.title3, design: .rounded, weight: .bold))

                HStack(spacing: 16) {
                    ResultMetric(label: "用时", value: appModel.formattedDuration(summary.result.duration), color: BDColor.primaryBlue)
                    ResultMetric(label: "错误", value: "\(summary.result.mistakeCount)", color: BDColor.error)
                    ResultMetric(label: "难度", value: summary.result.difficulty.shortLabel, color: BDColor.green)
                }

                if let eval = summary.difficultyEvaluation, case let .promote(to) = eval.recommendation {
                    Button("接受升级到 \(to.displayName)") {
                        appModel.acceptSchulteDifficultyRecommendation(to)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                }

                HStack(spacing: 16) {
                    Button { dismiss() } label: {
                        Text("继续").font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white).padding(.horizontal, 28).padding(.vertical, 12)
                            .background(Capsule().fill(BDGradient.primaryBlue))
                    }
                    .buttonStyle(.plain)

                    Button { appModel.cancelSchulteSession(); dismiss() } label: {
                        Text("结束训练").font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(.secondary).padding(.horizontal, 20).padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(28)
            .frame(maxWidth: 420)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.regularMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(BDColor.cardStroke, lineWidth: 1))
                    .shadow(color: .black.opacity(0.15), radius: 30, y: 10)
            )
            .scaleEffect(appeared ? 1 : 0.92).opacity(appeared ? 1 : 0)
        }
        .onAppear { withAnimation(.spring(duration: 0.4, bounce: 0.25)) { appeared = true } }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { appModel.dismissSchulteResult() }
    }
}

private struct ResultMetric: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Text(label).font(.system(.caption, design: .rounded, weight: .medium)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(color).monospacedDigit()
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color.opacity(0.08)))
    }
}
