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
        VStack(spacing: 16) {
            Image(systemName: "eye.fill")
                .font(.system(size: 48))
                .foregroundStyle(BDColor.changeDetectionAccent.opacity(0.6))
            Text("变更检测训练")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text("记住方块颜色，判断是否发生变化")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
            Text("核心指标：d' 与集合大小")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
            Text("起始集合 \(appModel.settings.changeDetectionInitialSetSize)，正确率稳定后本局内会提高集合大小。")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(BDColor.textSecondary)

            Button {
                appModel.startChangeDetectionSession()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("开始训练")
                }
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 40).padding(.vertical, 16)
                .background(Capsule().fill(BDColor.changeDetectionAccent))
            }
            .buttonStyle(.plain)
        }
    }

    private func activeView(engine: ChangeDetectionEngine) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("集合大小 \(engine.currentSetSize)  •  试次 \(engine.currentTrialIndex + 1)")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)

                BDFeedbackNote(text: feedbackText(engine), color: BDColor.changeDetectionAccent)
            }

            BDTrainingStage(accent: BDColor.changeDetectionAccent) {
                phaseContent(engine: engine)
            }
            .frame(width: 300, height: 300)

            if engine.phase == .probe {
                HStack(spacing: 20) {
                    Button {
                        _ = appModel.handleChangeDetectionResponse(changed: false)
                    } label: {
                        Text("没变")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28).padding(.vertical, 14)
                            .background(Capsule().fill(BDColor.teal))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("1", modifiers: [])

                    Button {
                        _ = appModel.handleChangeDetectionResponse(changed: true)
                    } label: {
                        Text("变了")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28).padding(.vertical, 14)
                            .background(Capsule().fill(BDColor.choiceRTAccent))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("2", modifiers: [])
                }
            }

            ProgressView(value: engine.completionFraction)
                .tint(BDColor.changeDetectionAccent)
                .frame(maxWidth: 300)

            Button("取消") { appModel.cancelChangeDetectionSession() }
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(BDColor.error)
                .buttonStyle(.plain)
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
            }
        case .retention:
            Text("+")
                .font(.system(size: 36, weight: .light, design: .rounded))
                .foregroundStyle(.secondary)
        case .probe:
            if let trial = engine.currentTrial {
                colorGridView(colors: trial.probeColors, positions: trial.positions)
            }
        case .feedback(let correct):
            VStack(spacing: 8) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(correct ? BDColor.green : BDColor.error)
                Text(correct ? "变化判断正确" : "重新检查变化是否出现")
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)
            }
        default:
            Color.clear.frame(height: 1)
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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(colorPalette[safeColorIdx])
                    .frame(width: 44, height: 44)
                    .position(x: pos.x * geo.size.width, y: pos.y * geo.size.height)
            }
        }
    }

    private func resultView(metrics: ChangeDetectionMetrics) -> some View {
        BDResultPanel(title: "变更检测完成", accent: BDColor.changeDetectionAccent) {
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
                .buttonStyle(.bordered)
        }
    }

    private func feedbackText(_ engine: ChangeDetectionEngine) -> String {
        switch engine.phase {
        case .encoding:
            return "编码颜色与位置"
        case .retention:
            return "保持刚才的颜色布局"
        case .probe:
            return "判断是否出现变化"
        case .feedback(let correct):
            guard let trial = engine.currentTrial else {
                return correct ? "正确" : "错误"
            }
            if correct {
                return trial.isChangePresent ? "变化被正确识别" : "无变化被正确确认"
            }
            return trial.isChangePresent ? "本轮实际上发生了变化" : "本轮实际上没有变化"
        default:
            return coordinator.statusMessage
        }
    }
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
