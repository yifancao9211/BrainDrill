import SwiftUI

struct GoNoGoTrainingView: View {
    @Environment(AppModel.self) private var appModel

    private var coordinator: GoNoGoCoordinator { appModel.goNoGo }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            if let engine = coordinator.engine, !engine.isComplete {
                activeView(engine: engine)
            } else if let result = coordinator.lastResult, let m = result.goNoGoMetrics {
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
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundStyle(BDColor.goNoGoAccent.opacity(0.6))
            Text("Go/No-Go 抑制力训练")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text("绿色圆形 → 按空格键    红色方形 → 忍住不动")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("核心指标：No-Go 正确率 与 d'")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
            if appModel.settings.adaptiveDifficultyEnabled {
                Text("当前推荐档位 L\(appModel.adaptiveState(for: .goNoGo).recommendedStartLevel) · 每局 2 个 block")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(BDColor.textSecondary)
            }

            Button {
                appModel.startGoNoGoSession()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("开始训练")
                }
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 40).padding(.vertical, 16)
                .background(Capsule().fill(BDColor.goNoGoAccent))
            }
            .buttonStyle(.plain)
        }
    }

    private func activeView(engine: GoNoGoEngine) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("试次 \(engine.currentTrialIndex + 1)/\(engine.trials.count)")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)
                Text("L\(engine.currentLevel) · Block \(engine.currentBlock + 1)/\(engine.totalBlocks)")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)

                BDFeedbackNote(text: feedbackText(engine), color: BDColor.goNoGoAccent)
            }

            BDTrainingStage(accent: BDColor.goNoGoAccent) {
                phaseContent(engine: engine)
                    .frame(height: 170)
            }

            if engine.phase == .stimulus {
                Button {
                    appModel.handleGoNoGoTap()
                } label: {
                    Text("按空格或点击")
                        .font(.system(.callout, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])
            }

            ProgressView(value: engine.completionFraction)
                .tint(BDColor.goNoGoAccent)
                .frame(maxWidth: 300)

            Button("取消") { appModel.cancelGoNoGoSession() }
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(BDColor.error)
                .buttonStyle(.plain)
        }
        .onAppear { schedulePhase(engine) }
        .onChange(of: engine.phase) { _, _ in schedulePhase(engine) }
    }

    @ViewBuilder
    private func phaseContent(engine: GoNoGoEngine) -> some View {
        switch engine.phase {
        case .fixation:
            Text("+")
                .font(.system(size: 48, weight: .light, design: .rounded))
                .foregroundStyle(.secondary)
        case .stimulus:
            if let trial = engine.currentTrial {
                if trial.stimulusType == .go {
                    Circle().fill(BDColor.green).frame(width: 120, height: 120)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(BDColor.error).frame(width: 120, height: 120)
                }
            }
        case .feedback(let correct):
            VStack(spacing: 8) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(correct ? BDColor.green : BDColor.error)
                Text(correct ? "控制稳定" : "抑制或启动判断出错")
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)
            }
        default:
            Color.clear.frame(height: 1)
        }
    }

    private func schedulePhase(_ engine: GoNoGoEngine) {
        switch engine.phase {
        case .idle:
            engine.beginTrial()
        case .fixation:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.currentSpec.fixationDurationMs)) {
                guard engine.phase == .fixation else { return }
                engine.showStimulus()
            }
        case .stimulus:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.currentSpec.responseWindowMs)) {
                guard engine.phase == .stimulus else { return }
                engine.recordTimeout()
            }
        case .feedback:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(220)) {
                engine.advanceToNext()
                if engine.isComplete {
                    appModel.finalizeGoNoGoIfComplete()
                }
            }
        case .iti:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.randomITI())) {
                engine.beginTrial()
            }
        case let .blockBreak(_, _, nextLevel):
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(550)) {
                guard case .blockBreak = engine.phase else { return }
                engine.startNextBlock(level: nextLevel)
            }
        default:
            break
        }
    }

    private func resultView(metrics: GoNoGoMetrics) -> some View {
        BDResultPanel(title: "Go/No-Go 完成", accent: BDColor.goNoGoAccent) {
            HStack(spacing: 16) {
                ResultCard(label: "d'", value: String(format: "%.2f", metrics.dPrime), color: BDColor.goNoGoAccent)
                ResultCard(label: "No-Go正确", value: "\(Int(metrics.noGoAccuracy * 100))%", color: BDColor.green)
                ResultCard(label: "Go RT", value: "\(Int(metrics.goRT * 1000))ms", color: BDColor.warm)
            }
            .frame(maxWidth: 400)

            Button("关闭") { appModel.dismissGoNoGoResult() }
                .buttonStyle(.bordered)
        }
    }

    private func feedbackText(_ engine: GoNoGoEngine) -> String {
        switch engine.phase {
        case .fixation:
            return "绿色启动，红色抑制"
        case .stimulus:
            if engine.currentTrial?.stimulusType == .go {
                return "Go 试次，立刻点击"
            }
            return "No-Go 试次，保持不动"
        case .feedback(let correct):
            guard let trial = engine.currentTrial else {
                return correct ? "正确" : "错误"
            }
            switch (trial.stimulusType, correct) {
            case (.go, true):
                return "Go 试次命中"
            case (.go, false):
                return "这是 Go 试次，应该点击"
            case (.noGo, true):
                return "No-Go 试次抑制成功"
            case (.noGo, false):
                return "这是 No-Go 试次，应该忍住"
            }
        case let .blockBreak(_, outcome, nextLevel):
            switch outcome {
            case .promote:
                return "控制稳定，升到 L\(nextLevel)"
            case .demote:
                return "本 block 调整到 L\(nextLevel)"
            case .stay:
                return "本 block 保持 L\(nextLevel)"
            }
        default:
            return coordinator.statusMessage
        }
    }
}

private struct ResultCard: View {
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
