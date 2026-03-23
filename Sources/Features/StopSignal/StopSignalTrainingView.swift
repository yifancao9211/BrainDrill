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
        VStack(spacing: 16) {
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(BDColor.stopSignalAccent.opacity(0.6))
            Text("Stop-Signal 训练")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text("看到箭头按方向键 ←→，出现红点时忍住不按")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("核心指标：SSRT（停止信号反应时）")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

            Button {
                appModel.startStopSignalSession()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("开始训练")
                }
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 40).padding(.vertical, 16)
                .background(Capsule().fill(BDColor.stopSignalAccent))
            }
            .buttonStyle(.plain)
        }
    }

    private func activeView(engine: StopSignalEngine) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("试次 \(engine.currentTrialIndex + 1)/\(engine.trials.count)  •  SSD \(engine.currentSSD)ms")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)

                BDFeedbackNote(text: feedbackText(engine), color: BDColor.stopSignalAccent)
            }

            BDTrainingStage(accent: BDColor.stopSignalAccent) {
                phaseContent(engine: engine)
                    .frame(height: 140)
            }

            let canRespond = engine.phase == .stimulus || engine.phase == .stopSignalShown
            HStack(spacing: 40) {
                Button { _ = appModel.handleStopSignalResponse(.left) } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 28, weight: .bold))
                        .frame(width: 70, height: 70)
                        .background(Circle().fill(BDColor.stopSignalAccent.opacity(canRespond ? 0.15 : 0.05)))
                        .foregroundStyle(BDColor.stopSignalAccent.opacity(canRespond ? 1 : 0.3))
                }
                .buttonStyle(.plain)
                .disabled(!canRespond)
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button { _ = appModel.handleStopSignalResponse(.right) } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 28, weight: .bold))
                        .frame(width: 70, height: 70)
                        .background(Circle().fill(BDColor.stopSignalAccent.opacity(canRespond ? 0.15 : 0.05)))
                        .foregroundStyle(BDColor.stopSignalAccent.opacity(canRespond ? 1 : 0.3))
                }
                .buttonStyle(.plain)
                .disabled(!canRespond)
                .keyboardShortcut(.rightArrow, modifiers: [])
            }

            ProgressView(value: engine.completionFraction)
                .tint(BDColor.stopSignalAccent)
                .frame(maxWidth: 300)

            Button("取消") { appModel.cancelStopSignalSession() }
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(BDColor.error)
                .buttonStyle(.plain)
        }
        .onAppear { schedulePhase(engine) }
        .onChange(of: engine.phase) { _, _ in schedulePhase(engine) }
    }

    @ViewBuilder
    private func phaseContent(engine: StopSignalEngine) -> some View {
        switch engine.phase {
        case .fixation:
            Text("+")
                .font(.system(size: 48, weight: .light, design: .rounded))
                .foregroundStyle(.secondary)
        case .stimulus:
            if let trial = engine.currentTrial {
                Image(systemName: trial.correctDirection == .left ? "arrow.left" : "arrow.right")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(BDColor.primaryBlue)
            }
        case .stopSignalShown:
            ZStack {
                if let trial = engine.currentTrial {
                    Image(systemName: trial.correctDirection == .left ? "arrow.left" : "arrow.right")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(BDColor.primaryBlue)
                }
                Circle()
                    .fill(BDColor.stopSignalAccent)
                    .frame(width: 30, height: 30)
                    .offset(y: -40)
            }
        case .feedback(let correct):
            VStack(spacing: 8) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(correct ? BDColor.green : BDColor.error)
                Text(correct ? "本次控制正确" : "停止信号后未成功抑制")
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)
            }
        default:
            Color.clear.frame(height: 1)
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
            HStack(spacing: 16) {
                SSResultCard(label: "SSRT", value: "\(Int(metrics.ssrt * 1000))ms", color: BDColor.stopSignalAccent)
                SSResultCard(label: "抑制率", value: "\(Int(metrics.inhibitionRate * 100))%", color: BDColor.green)
                SSResultCard(label: "Go RT", value: "\(Int(metrics.goRT * 1000))ms", color: BDColor.warm)
            }
            .frame(maxWidth: 400)

            Button("关闭") { appModel.dismissStopSignalResult() }
                .buttonStyle(.bordered)
        }
    }

    private func feedbackText(_ engine: StopSignalEngine) -> String {
        switch engine.phase {
        case .fixation:
            return "准备对箭头方向做出反应"
        case .stimulus:
            return "看到箭头立即响应"
        case .stopSignalShown:
            return "红点出现后必须忍住不按"
        case .feedback(let correct):
            guard let trial = engine.currentTrial else {
                return correct ? "正确" : "错误"
            }
            if trial.hasStopSignal {
                return correct ? "Stop 试次抑制成功" : "Stop 试次抑制失败"
            }
            return correct ? "Go 试次方向正确" : "Go 试次方向判断错误"
        default:
            return coordinator.statusMessage
        }
    }
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
