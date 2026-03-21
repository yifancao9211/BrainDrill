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
            Text("试次 \(engine.currentTrialIndex + 1)/\(engine.trials.count)")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

            phaseContent(engine: engine)
                .frame(height: 80)

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
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(correct ? BDColor.green : BDColor.error)
        default:
            Color.clear.frame(height: 1)
        }
    }

    private func schedulePhase(_ engine: FlankerEngine) {
        switch engine.phase {
        case .idle:
            engine.beginTrial()
        case .fixation:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                guard engine.phase == .fixation else { return }
                engine.showStimulus()
            }
        case .stimulus:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.config.stimulusDurationMs)) {
                guard engine.phase == .stimulus else { return }
                engine.enterResponseWindow()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.config.responseWindowMs)) {
                guard engine.phase == .stimulus || engine.phase == .waitingForResponse else { return }
                engine.recordTimeout()
            }
        case .feedback:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
                engine.advanceToNext()
                if engine.isComplete {
                    appModel.finalizeFlankerIfComplete()
                }
            }
        case .iti:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.randomITI())) {
                engine.beginTrial()
            }
        default:
            break
        }
    }

    private func resultView(metrics: FlankerMetrics) -> some View {
        VStack(spacing: 20) {
            Text("Flanker 完成")
                .font(.system(.title2, design: .rounded, weight: .bold))
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
