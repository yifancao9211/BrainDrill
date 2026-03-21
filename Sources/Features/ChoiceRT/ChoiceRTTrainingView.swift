import SwiftUI

struct ChoiceRTTrainingView: View {
    @Environment(AppModel.self) private var appModel

    private var coordinator: ChoiceRTCoordinator { appModel.choiceRT }

    private let stimulusColors: [Color] = [.red, .blue, .green, .yellow]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            if let engine = coordinator.engine, !engine.isComplete {
                activeView(engine: engine)
            } else if let result = coordinator.lastResult, let m = result.choiceRTMetrics {
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
            Image(systemName: "bolt.fill")
                .font(.system(size: 48))
                .foregroundStyle(BDColor.choiceRTAccent.opacity(0.6))
            Text("选择反应时训练")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text("看到颜色后，快速按对应按键")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
            Text("核心指标：中位反应时 (RT)")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(0..<appModel.settings.choiceRTChoiceCount, id: \.self) { i in
                    let palette = ChoiceRTStimulus.palette
                    if i < palette.count {
                        HStack(spacing: 4) {
                            Circle().fill(stimulusColors[palette[i].colorIndex]).frame(width: 14, height: 14)
                            Text("→ 按键 \(i + 1)")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Button {
                appModel.startChoiceRTSession()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("开始训练")
                }
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 40).padding(.vertical, 16)
                .background(Capsule().fill(BDColor.choiceRTAccent))
            }
            .buttonStyle(.plain)
        }
    }

    private func activeView(engine: ChoiceRTEngine) -> some View {
        VStack(spacing: 24) {
            Text("试次 \(engine.currentTrialIndex + 1)/\(engine.trials.count)")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

            Group {
                switch engine.phase {
                case .fixation:
                    Text("+")
                        .font(.system(size: 64, weight: .light, design: .rounded))
                        .foregroundStyle(.secondary)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.config.fixationMs)) {
                                guard engine.phase == .fixation else { return }
                                engine.showStimulus()
                            }
                        }
                case .stimulus:
                    if let trial = engine.currentTrial {
                        Circle()
                            .fill(stimulusColors[trial.stimulus.colorIndex])
                            .frame(width: 100, height: 100)
                            .transition(.scale.combined(with: .opacity))
                    }
                case .feedback(let correct):
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(correct ? BDColor.green : BDColor.error)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
                                engine.advanceToNext()
                                if !engine.isComplete {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.randomITI())) {
                                        engine.beginTrial()
                                    }
                                } else {
                                    appModel.finalizeChoiceRTIfComplete()
                                }
                            }
                        }
                case .iti:
                    Color.clear.frame(height: 100)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.randomITI())) {
                                engine.beginTrial()
                            }
                        }
                default:
                    EmptyView()
                        .onAppear {
                            engine.beginTrial()
                        }
                }
            }
            .frame(height: 120)
            .animation(.easeInOut(duration: 0.15), value: engine.phase)

            HStack(spacing: 12) {
                ForEach(0..<engine.config.choiceCount, id: \.self) { i in
                    Button {
                        _ = appModel.handleChoiceRTResponse(i)
                    } label: {
                        let palette = ChoiceRTStimulus.palette
                        Text(i < palette.count ? palette[i].label : "\(i+1)")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 48)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(i < stimulusColors.count ? stimulusColors[palette[i].colorIndex] : .gray))
                    }
                    .buttonStyle(.plain)
                    .disabled(engine.phase != .stimulus)
                }
            }

            ProgressView(value: engine.completionFraction)
                .tint(BDColor.choiceRTAccent)
                .frame(maxWidth: 300)

            Button("取消") { appModel.cancelChoiceRTSession() }
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(BDColor.error)
                .buttonStyle(.plain)
        }
    }

    private func resultView(metrics: ChoiceRTMetrics) -> some View {
        VStack(spacing: 20) {
            Text("选择反应时完成")
                .font(.system(.title2, design: .rounded, weight: .bold))
            HStack(spacing: 16) {
                CRTResultCard(label: "中位 RT", value: "\(Int(metrics.medianRT * 1000))ms", color: BDColor.choiceRTAccent)
                CRTResultCard(label: "正确率", value: "\(Int(metrics.accuracy * 100))%", color: BDColor.green)
                CRTResultCard(label: "RT SD", value: "\(Int(metrics.rtStandardDeviation * 1000))ms", color: BDColor.warm)
            }
            .frame(maxWidth: 400)

            if metrics.postErrorSlowing > 0 {
                Text("错后减速：\(Int(metrics.postErrorSlowing * 1000))ms")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Button("关闭") { appModel.dismissChoiceRTResult() }
                .buttonStyle(.bordered)
        }
    }
}

private struct CRTResultCard: View {
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
