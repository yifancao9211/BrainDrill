import SwiftUI

struct ChangeDetectionTrainingView: View {
    @Environment(AppModel.self) private var appModel

    private var coordinator: ChangeDetectionCoordinator { appModel.changeDetection }

    private let colorPalette: [Color] = [
        .red, .blue, .green, .yellow, .purple, .orange, .pink, .cyan, .mint
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            if let engine = coordinator.engine, !engine.isComplete {
                activeView(engine: engine)
            } else if let result = coordinator.lastResult, let m = result.changeDetectionMetrics {
                resultView(metrics: m)
            } else {
                idleView
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var idleView: some View {
        SurfaceCard(title: "变更检测", subtitle: "统一进入训练壳层完成编码、保持与探测。", accent: BDColor.changeDetectionAccent) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    InfoPill(title: "起始集合 \(appModel.settings.changeDetectionInitialSetSize)", accent: BDColor.changeDetectionAccent)
                    InfoPill(title: "核心指标 d'", accent: BDColor.green)
                }

                BDInsightCard(
                    title: "训练说明",
                    bodyText: "先记住编码画面，短暂保持后判断探测画面是否发生变化。正确率稳定后集合大小会提高。",
                    accent: BDColor.changeDetectionAccent
                )

                Button("开始训练") {
                    appModel.startChangeDetectionSession()
                }
                .buttonStyle(BDPrimaryButton(accent: BDColor.changeDetectionAccent))
            }
        }
    }

    private func activeView(engine: ChangeDetectionEngine) -> some View {
        BDTrainingShell(accent: BDColor.changeDetectionAccent) {
            VStack(spacing: 8) {
                Text("集合大小 \(engine.currentSetSize)  •  试次 \(engine.currentTrialIndex + 1)")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)
            }
        } stage: {
            phaseContent(engine: engine)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(width: 360, height: 360)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: engine.phase)
        } footer: {
            VStack(spacing: 16) {
                if engine.phase == .probe {
                    HStack(spacing: 20) {
                        Button("没变") {
                            _ = appModel.handleChangeDetectionResponse(changed: false)
                        }
                        .buttonStyle(BDSecondaryButton(accent: BDColor.teal))
                        .keyboardShortcut("1", modifiers: [])

                        Button("变了") {
                            _ = appModel.handleChangeDetectionResponse(changed: true)
                        }
                        .buttonStyle(BDPrimaryButton(accent: BDColor.choiceRTAccent))
                        .keyboardShortcut("2", modifiers: [])
                    }
                }

                ProgressView(value: engine.completionFraction)
                    .tint(BDColor.changeDetectionAccent)
                    .frame(maxWidth: 300)

                Button("取消") { appModel.cancelChangeDetectionSession() }
                    .buttonStyle(BDSecondaryButton(accent: BDColor.error))
            }
        }
        .onAppear { schedulePhase(engine) }
        .onChange(of: engine.phase) { _, _ in schedulePhase(engine) }
    }

    @ViewBuilder
    private func phaseContent(engine: ChangeDetectionEngine) -> some View {
        switch engine.phase {
        case .encoding:
            if let trial = engine.currentTrial {
                colorGridView(colors: trial.originalColors, positions: trial.positions)
                    .transition(.opacity)
            }
        case .retention:
            Text("+")
                .font(.system(size: 64, weight: .light, design: .rounded))
                .foregroundStyle(.tertiary)
        case .probe:
            if let trial = engine.currentTrial {
                colorGridView(colors: trial.probeColors, positions: trial.positions)
                    .transition(.opacity)
            }
        case .feedback(let correct):
            VStack(spacing: 8) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(correct ? BDColor.green : BDColor.error)
                Text(correct ? "变化判断正确" : "重新检查变化是否出现")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(correct ? BDColor.green : BDColor.error)
            }
            .transition(.scale.combined(with: .opacity))
        default:
            Color.clear
        }
    }

    private func schedulePhase(_ engine: ChangeDetectionEngine) {
        switch engine.phase {
        case .idle:
            engine.beginTrial()
        case .encoding:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.config.encodingMs)) {
                guard engine.phase == .encoding else { return }
                engine.startRetention()
            }
        case .retention:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.config.retentionMs)) {
                guard engine.phase == .retention else { return }
                engine.showProbe()
            }
        case .feedback:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(350)) {
                engine.advanceToNext()
                if engine.isComplete {
                    appModel.finalizeChangeDetectionIfComplete()
                }
            }
        case .iti:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(220)) {
                engine.beginTrial()
            }
        default:
            break
        }
    }

    private func colorGridView(colors: [Int], positions: [CGPoint]) -> some View {
        GeometryReader { geo in
            ForEach(Array(colors.enumerated()), id: \.offset) { idx, colorIdx in
                let pos = idx < positions.count ? positions[idx] : CGPoint(x: 0.5, y: 0.5)
                let safeColorIdx = min(colorIdx, colorPalette.count - 1)
                let c = colorPalette[safeColorIdx]
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(c)
                    .frame(width: 52, height: 52)
                    .shadow(color: c.opacity(0.4), radius: 8, y: 4)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.3), lineWidth: 2))
                    .position(x: pos.x * geo.size.width, y: pos.y * geo.size.height)
            }
        }
    }

    private func resultView(metrics: ChangeDetectionMetrics) -> some View {
        BDResultPanel(title: "变更检测完成", accent: BDColor.changeDetectionAccent) {
            Text("查看本轮视觉保持表现")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(BDColor.changeDetectionAccent)

            HStack(spacing: 16) {
                CDResultCard(label: "d'", value: String(format: "%.2f", metrics.dPrime), color: BDColor.changeDetectionAccent)
                CDResultCard(label: "正确率", value: "\(Int(metrics.accuracy * 100))%", color: BDColor.green)
                CDResultCard(label: "最大集合", value: "\(metrics.maxSetSize)", color: BDColor.warm)
            }
            .frame(maxWidth: 400)

            if appModel.settings.adaptiveDifficultyEnabled {
                Text("下次训练将从集合大小 \(appModel.settings.changeDetectionInitialSetSize) 开始。")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(BDColor.textSecondary)
            }

            Button("关闭") { appModel.dismissChangeDetectionResult() }
                .buttonStyle(BDSecondaryButton(accent: BDColor.changeDetectionAccent))
        }
    }

    // feedbackText removed
}

private struct CDResultCard: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Text(label).font(.system(.caption, design: .rounded, weight: .medium)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity).padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color.opacity(0.08)))
    }
}
