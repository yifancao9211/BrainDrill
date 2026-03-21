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
            Text("绿色圆形 → 快速点击    红色方形 → 忍住不动")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("核心指标：No-Go 正确率 与 d'")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

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
            Text("试次 \(engine.currentTrialIndex + 1)/\(engine.trials.count)")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

            Group {
                switch engine.phase {
                case .fixation:
                    Text("+")
                        .font(.system(size: 48, weight: .light, design: .rounded))
                        .foregroundStyle(.secondary)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                                guard engine.phase == .fixation else { return }
                                engine.showStimulus()
                            }
                        }
                case .stimulus:
                    if let trial = engine.currentTrial {
                        Button {
                            appModel.handleGoNoGoTap()
                        } label: {
                            Group {
                                if trial.stimulusType == .go {
                                    Circle().fill(BDColor.green).frame(width: 120, height: 120)
                                } else {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(BDColor.error).frame(width: 120, height: 120)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                        .keyboardShortcut(.space, modifiers: [])
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.config.responseWindowMs)) {
                                guard engine.phase == .stimulus else { return }
                                engine.recordTimeout()
                                handleGoNoGoAdvance(engine: engine)
                            }
                        }
                    }
                case .feedback(let correct):
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(correct ? BDColor.green : BDColor.error)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
                                handleGoNoGoAdvance(engine: engine)
                            }
                        }
                case .iti:
                    Color.clear.frame(height: 120)
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
            .frame(height: 130)
            .animation(.easeInOut(duration: 0.15), value: engine.phase)

            ProgressView(value: engine.completionFraction)
                .tint(BDColor.goNoGoAccent)
                .frame(maxWidth: 300)

            Button("取消") { appModel.cancelGoNoGoSession() }
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(BDColor.error)
                .buttonStyle(.plain)
        }
    }

    private func handleGoNoGoAdvance(engine: GoNoGoEngine) {
        engine.advanceToNext()
        if engine.isComplete {
            appModel.finalizeGoNoGoIfComplete()
        }
    }

    private func resultView(metrics: GoNoGoMetrics) -> some View {
        VStack(spacing: 20) {
            Text("Go/No-Go 完成")
                .font(.system(.title2, design: .rounded, weight: .bold))
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
