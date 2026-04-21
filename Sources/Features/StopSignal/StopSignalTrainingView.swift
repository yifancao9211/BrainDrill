import SwiftUI

struct StopSignalTrainingView: View {
    @Environment(AppModel.self) private var appModel

    private var coordinator: StopSignalCoordinator { appModel.stopSignal }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            if let engine = coordinator.engine, !engine.isComplete {
                activeView(engine: engine)
            } else if let result = coordinator.lastResult, let m = result.stopSignalMetrics {
                resultView(metrics: m)
            } else {
                idleView
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var idleView: some View {
        SurfaceCard(title: "Stop-Signal", subtitle: "在统一训练壳层中完成反应启动与停止控制。", accent: BDColor.stopSignalAccent) {
            VStack(alignment: .leading, spacing: 16) {
                BDInsightCard(
                    title: "训练说明",
                    bodyText: "看到方向箭头按左右键，出现红色停止信号时立即抑制反应。核心观察指标是 SSRT。",
                    accent: BDColor.stopSignalAccent
                )

                Button("开始训练") {
                    appModel.startStopSignalSession()
                }
                .buttonStyle(BDPrimaryButton(accent: BDColor.stopSignalAccent))
            }
        }
    }

    private func activeView(engine: StopSignalEngine) -> some View {
        BDTrainingShell(accent: BDColor.stopSignalAccent) {
            VStack(spacing: 8) {
                Text("试次 \(engine.currentTrialIndex + 1)/\(engine.trials.count)")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)
            }
        } stage: {
            phaseContent(engine: engine)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(height: 280)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: engine.phase)
        } footer: {
            let canRespond = engine.phase == .stimulus || engine.phase == .stopSignalShown
            VStack(spacing: 16) {
                HStack(spacing: 40) {
                    Button { _ = appModel.handleStopSignalResponse(.left) } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 28, weight: .bold))
                            .frame(width: 70, height: 70)
                            .background(Circle().fill(BDColor.stopSignalAccent.opacity(canRespond ? 0.15 : 0.05)))
                            .foregroundStyle(BDColor.stopSignalAccent.opacity(canRespond ? 1 : 0.3))
                    }
                    .buttonStyle(BDSpringPressStyle())
                    .disabled(!canRespond)
                    .keyboardShortcut(.leftArrow, modifiers: [])

                    Button { _ = appModel.handleStopSignalResponse(.right) } label: {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 28, weight: .bold))
                            .frame(width: 70, height: 70)
                            .background(Circle().fill(BDColor.stopSignalAccent.opacity(canRespond ? 0.15 : 0.05)))
                            .foregroundStyle(BDColor.stopSignalAccent.opacity(canRespond ? 1 : 0.3))
                    }
                    .buttonStyle(BDSpringPressStyle())
                    .disabled(!canRespond)
                    .keyboardShortcut(.rightArrow, modifiers: [])
                }

                ProgressView(value: engine.completionFraction)
                    .tint(BDColor.stopSignalAccent)
                    .frame(maxWidth: 300)

                Button("取消") { appModel.cancelStopSignalSession() }
                    .buttonStyle(BDSecondaryButton(accent: BDColor.error))
            }
        }
        .onAppear { schedulePhase(engine) }
        .onChange(of: engine.phase) { _, _ in schedulePhase(engine) }
    }

    @ViewBuilder
    private func phaseContent(engine: StopSignalEngine) -> some View {
        switch engine.phase {
        case .fixation:
            Text("+")
                .font(.system(size: 80, weight: .light, design: .rounded))
                .foregroundStyle(.tertiary)
                .transition(.opacity)
        case .stimulus:
            if let trial = engine.currentTrial {
                Image(systemName: trial.correctDirection == .left ? "arrow.left" : "arrow.right")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(BDColor.primaryBlue)
                    .frame(width: 140, height: 140)
                    .background(Color.clear.bdPanelSurface(.primary, cornerRadius: 40))
                    .shadow(color: BDColor.primaryBlue.opacity(0.2), radius: 24, y: 8)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        case .stopSignalShown:
            ZStack {
                if let trial = engine.currentTrial {
                    Image(systemName: trial.correctDirection == .left ? "arrow.left" : "arrow.right")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundStyle(BDColor.primaryBlue)
                        .frame(width: 140, height: 140)
                        .background(Color.clear.bdPanelSurface(.primary, cornerRadius: 40))
                }
                Circle()
                    .strokeBorder(BDColor.error, lineWidth: 10)
                    .background(Circle().fill(BDColor.error.opacity(0.15)))
                    .frame(width: 170, height: 170)
                    .shadow(color: BDColor.error.opacity(0.8), radius: 20, y: 0)
                    .transition(.scale(scale: 2.5).combined(with: .opacity))
            }
        case .feedback(let correct):
            VStack(spacing: 8) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(correct ? BDColor.green : BDColor.error)
                Text(correct ? "本次控制正确" : "停止信号后未成功抑制")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(correct ? BDColor.green : BDColor.error)
            }
            .transition(.scale.combined(with: .opacity))
            .offset(x: correct ? 0 : -8)
        default:
            Color.clear
        }
    }

    private func schedulePhase(_ engine: StopSignalEngine) {
        switch engine.phase {
        case .idle:
            engine.beginTrial()
        case .fixation:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.config.fixationMs)) {
                guard engine.phase == .fixation else { return }
                engine.showStimulus()
                scheduleStopOrTimeout(engine)
            }
        case .feedback:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(220)) {
                engine.advanceToNext()
                if engine.isComplete {
                    appModel.finalizeStopSignalIfComplete()
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

    private func scheduleStopOrTimeout(_ engine: StopSignalEngine) {
        guard let trial = engine.currentTrial else { return }

        if trial.hasStopSignal {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.currentSSD)) {
                guard engine.phase == .stimulus else { return }
                engine.showStopSignal()

                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.config.responseWindowMs - engine.currentSSD)) {
                    guard engine.phase == .stopSignalShown else { return }
                    appModel.handleStopSignalStopTimeout()
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.config.responseWindowMs)) {
                guard engine.phase == .stimulus else { return }
                appModel.handleStopSignalGoTimeout()
            }
        }
    }

    private func resultView(metrics: StopSignalMetrics) -> some View {
        BDResultPanel(title: "Stop-Signal 完成", accent: BDColor.stopSignalAccent) {
            Text("查看本轮停止控制表现")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(BDColor.stopSignalAccent)

            HStack(spacing: 16) {
                SSResultCard(label: "SSRT", value: "\(Int(metrics.ssrt * 1000))ms", color: BDColor.stopSignalAccent)
                SSResultCard(label: "抑制率", value: "\(Int(metrics.inhibitionRate * 100))%", color: BDColor.green)
                SSResultCard(label: "Go RT", value: "\(Int(metrics.goRT * 1000))ms", color: BDColor.warm)
            }
            .frame(maxWidth: 400)

            Button("关闭") { appModel.dismissStopSignalResult() }
                .buttonStyle(BDSecondaryButton(accent: BDColor.stopSignalAccent))
        }
    }

    // feedbackText removed
}

private struct SSResultCard: View {
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
