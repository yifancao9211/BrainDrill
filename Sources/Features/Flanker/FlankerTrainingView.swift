import SwiftUI

struct FlankerTrainingView: View {
    @Environment(AppModel.self) private var appModel

    private var coordinator: FlankerCoordinator { appModel.flanker }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            if let engine = coordinator.engine, !engine.isComplete {
                activeView(engine: engine)
            } else if let result = coordinator.lastResult, let m = result.flankerMetrics {
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
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 48))
                .foregroundStyle(BDColor.flankerAccent.opacity(0.6))
            Text("Flanker 反应力训练")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text("快速判断中间箭头方向（键盘 ←→），忽略两侧干扰")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("核心指标：冲突代价 = 反向RT - 同向RT")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
            if appModel.settings.adaptiveDifficultyEnabled {
                Text("当前推荐档位 L\(appModel.adaptiveState(for: .flanker).recommendedStartLevel) · 每局 2 个 block")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(BDColor.textSecondary)
            }

            Button {
                appModel.startFlankerSession()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("开始训练")
                }
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 40).padding(.vertical, 16)
                .background(Capsule().fill(BDColor.flankerAccent))
            }
            .buttonStyle(.plain)
        }
    }

    private func activeView(engine: FlankerEngine) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("试次 \(engine.currentTrialIndex + 1)/\(engine.trials.count)")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)
                Text("L\(engine.currentLevel) · Block \(engine.currentBlock + 1)/\(engine.totalBlocks)")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)

                BDFeedbackNote(text: feedbackText(engine), color: BDColor.flankerAccent)
            }

            BDTrainingStage(accent: BDColor.flankerAccent) {
                phaseContent(engine: engine)
                    .frame(height: 120)
            }

            let canRespond = engine.phase == .stimulus || engine.phase == .waitingForResponse
            HStack(spacing: 40) {
                Button { appModel.handleFlankerResponse(.left) } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 32, weight: .bold))
                        .frame(width: 80, height: 80)
                        .background(Circle().fill(BDColor.flankerAccent.opacity(canRespond ? 0.15 : 0.05)))
                        .foregroundStyle(BDColor.flankerAccent.opacity(canRespond ? 1 : 0.3))
                }
                .buttonStyle(.plain)
                .disabled(!canRespond)
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button { appModel.handleFlankerResponse(.right) } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 32, weight: .bold))
                        .frame(width: 80, height: 80)
                        .background(Circle().fill(BDColor.flankerAccent.opacity(canRespond ? 0.15 : 0.05)))
                        .foregroundStyle(BDColor.flankerAccent.opacity(canRespond ? 1 : 0.3))
                }
                .buttonStyle(.plain)
                .disabled(!canRespond)
                .keyboardShortcut(.rightArrow, modifiers: [])
            }

            ProgressView(value: engine.completionFraction)
                .tint(BDColor.flankerAccent)
                .frame(maxWidth: 300)

            Button("取消") { appModel.cancelFlankerSession() }
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(BDColor.error)
                .buttonStyle(.plain)
        }
        .onAppear { schedulePhase(engine) }
        .onChange(of: engine.phase) { _, _ in schedulePhase(engine) }
    }

    @ViewBuilder
    private func phaseContent(engine: FlankerEngine) -> some View {
        switch engine.phase {
        case .fixation:
            Text("+")
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        case .stimulus, .waitingForResponse:
            if let trial = engine.currentTrial {
                Text(trial.arrows)
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
            }
        case .feedback(let correct):
            VStack(spacing: 8) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(correct ? BDColor.green : BDColor.error)
                Text(correct ? "抓住了中间目标" : "注意只判断中间箭头")
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)
            }
        default:
            Color.clear.frame(height: 1)
        }
    }

    private func schedulePhase(_ engine: FlankerEngine) {
        switch engine.phase {
        case .idle:
            engine.beginTrial()
        case .fixation:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.currentSpec.fixationDurationMs)) {
                guard engine.phase == .fixation else { return }
                engine.showStimulus()
            }
        case .stimulus:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.currentSpec.stimulusDurationMs)) {
                guard engine.phase == .stimulus else { return }
                engine.enterResponseWindow()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.currentSpec.responseWindowMs)) {
                guard engine.phase == .stimulus || engine.phase == .waitingForResponse else { return }
                engine.recordTimeout()
            }
        case .feedback:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(220)) {
                engine.advanceToNext()
                if engine.isComplete {
                    appModel.finalizeFlankerIfComplete()
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

    private func resultView(metrics: FlankerMetrics) -> some View {
        BDResultPanel(title: "Flanker 完成", accent: BDColor.flankerAccent) {
            HStack(spacing: 16) {
                FResultCard(label: "冲突代价", value: "\(Int(metrics.conflictCost * 1000))ms", color: BDColor.flankerAccent)
                FResultCard(label: "正确率", value: "\(Int(metrics.accuracy * 100))%", color: BDColor.green)
                FResultCard(label: "试次", value: "\(metrics.totalTrials)", color: BDColor.warm)
            }
            .frame(maxWidth: 400)

            Button("关闭") { appModel.dismissFlankerResult() }
                .buttonStyle(.bordered)
        }
    }

    private func feedbackText(_ engine: FlankerEngine) -> String {
        switch engine.phase {
        case .fixation:
            return "保持注视，准备响应中央目标"
        case .stimulus, .waitingForResponse:
            if let trial = engine.currentTrial, trial.type == .incongruent {
                return "忽略两侧干扰箭头，只看中间"
            }
            return "快速判断中间箭头方向"
        case .feedback(let correct):
            return correct ? "正确聚焦目标" : "被干扰项影响了判断"
        case let .blockBreak(_, outcome, nextLevel):
            switch outcome {
            case .promote:
                return "本 block 升到 L\(nextLevel)"
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

private struct FResultCard: View {
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
