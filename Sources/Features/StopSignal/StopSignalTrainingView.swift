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
            Text("看到箭头按方向键，出现红色停止信号时忍住不按")
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
            Text("试次 \(engine.currentTrialIndex + 1)/\(engine.trials.count)  •  SSD \(engine.currentSSD)ms")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

            Group {
                switch engine.phase {
                case .fixation:
                    Text("+")
                        .font(.system(size: 48, weight: .light, design: .rounded))
                        .foregroundStyle(.secondary)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.config.fixationMs)) {
                                guard engine.phase == .fixation else { return }
                                engine.showStimulus()
                                scheduleStopOrTimeout(engine: engine)
                            }
                        }
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
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(correct ? BDColor.green : BDColor.error)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
                                engine.advanceToNext()
                                if engine.isComplete {
                                    appModel.finalizeStopSignalIfComplete()
                                } else {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.randomITI())) {
                                        engine.beginTrial()
                                    }
                                }
                            }
                        }
                case .iti:
                    Color.clear.frame(height: 80)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.randomITI())) {
                                engine.beginTrial()
                            }
                        }
                default:
                    EmptyView()
                        .onAppear { engine.beginTrial() }
                }
            }
            .frame(height: 100)

            HStack(spacing: 40) {
                let canRespond = engine.phase == .stimulus || engine.phase == .stopSignalShown
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
    }

    private func scheduleStopOrTimeout(engine: StopSignalEngine) {
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
        VStack(spacing: 20) {
            Text("Stop-Signal 完成")
                .font(.system(.title2, design: .rounded, weight: .bold))
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
