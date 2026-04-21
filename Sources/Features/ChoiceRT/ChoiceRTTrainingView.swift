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
        SurfaceCard(title: "选择反应时", subtitle: "在统一训练壳层里完成颜色映射、响应和结果回看。", accent: BDColor.choiceRTAccent) {
            VStack(alignment: .leading, spacing: 16) {
                if appModel.settings.adaptiveDifficultyEnabled {
                    Text("当前推荐档位 L\(appModel.adaptiveState(for: .choiceRT).recommendedStartLevel) · 每局 2 个 block")
                        .font(.system(.caption))
                        .foregroundStyle(BDColor.textSecondary)
                }

                BDInsightCard(
                    title: "训练说明",
                    bodyText: "看到颜色后，快速按对应键位。先熟悉映射，再压缩中位反应时和波动。",
                    accent: BDColor.choiceRTAccent
                )

                HStack(spacing: 12) {
                let idleChoiceCount = appModel.settings.adaptiveDifficultyEnabled
                    ? ChoiceRTSessionConfig(startingLevel: appModel.adaptiveState(for: .choiceRT).recommendedStartLevel).initialSpec.choiceCount
                    : appModel.settings.choiceRTChoiceCount
                ForEach(0..<idleChoiceCount, id: \.self) { i in
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
                Button("开始训练") {
                    appModel.startChoiceRTSession()
                }
                .buttonStyle(BDPrimaryButton(accent: BDColor.choiceRTAccent))
            }
        }
    }

    private func activeView(engine: ChoiceRTEngine) -> some View {
        BDTrainingShell(accent: BDColor.choiceRTAccent) {
            VStack(spacing: 8) {
                Text("试次 \(engine.currentTrialIndex + 1)/\(engine.trials.count)")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)
                Text("L\(engine.currentLevel) · Block \(engine.currentBlock + 1)/\(engine.totalBlocks)")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        } stage: {
            phaseContent(engine: engine)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(height: 240)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: engine.phase)
        } footer: {
            let canRespond = engine.phase == .stimulus
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    ForEach(0..<engine.currentSpec.choiceCount, id: \.self) { i in
                        let keyboardKeys: [KeyEquivalent] = ["1", "2", "3", "4"]
                        Button {
                            _ = appModel.handleChoiceRTResponse(i)
                        } label: {
                            let palette = ChoiceRTStimulus.palette
                            Text(i < palette.count ? palette[i].label : "\(i+1)")
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 72, height: 64)
                                .background(
                                    ZStack {
                                        Color.clear.bdPanelSurface(.primary, cornerRadius: 16)
                                        if i < stimulusColors.count {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(stimulusColors[palette[i].colorIndex].opacity(canRespond ? 1 : 0.2))
                                        }
                                    }
                                )
                                .shadow(color: (i < stimulusColors.count && canRespond) ? stimulusColors[palette[i].colorIndex].opacity(0.4) : .clear, radius: 10, y: 4)
                        }
                        .buttonStyle(BDSpringPressStyle())
                        .disabled(!canRespond)
                        .keyboardShortcut(i < keyboardKeys.count ? keyboardKeys[i] : "0", modifiers: [])
                    }
                }

                ProgressView(value: engine.completionFraction)
                    .tint(BDColor.choiceRTAccent)
                    .frame(maxWidth: 300)

                Button("取消") { appModel.cancelChoiceRTSession() }
                    .buttonStyle(BDSecondaryButton(accent: BDColor.error))
            }
        }
        .onAppear { schedulePhase(engine) }
        .onChange(of: engine.phase) { _, _ in schedulePhase(engine) }
    }

    @ViewBuilder
    private func phaseContent(engine: ChoiceRTEngine) -> some View {
        switch engine.phase {
        case .fixation:
            Text("+")
                .font(.system(size: 80, weight: .light, design: .rounded))
                .foregroundStyle(.tertiary)
                .transition(.opacity)
        case .stimulus:
            if let trial = engine.currentTrial {
                let c = stimulusColors[trial.stimulus.colorIndex]
                Circle()
                    .fill(c)
                    .frame(width: 120, height: 120)
                    .shadow(color: c.opacity(0.5), radius: 24, y: 8)
                    .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 4))
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        case .feedback(let correct):
            VStack(spacing: 8) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(correct ? BDColor.green : BDColor.error)
                Text(correct ? "按键映射正确" : "颜色与按键映射不匹配")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(correct ? BDColor.green : BDColor.error)
            }
            .transition(.scale.combined(with: .opacity))
            .offset(x: correct ? 0 : 8)
        default:
            Color.clear
        }
    }

    private func schedulePhase(_ engine: ChoiceRTEngine) {
        switch engine.phase {
        case .idle:
            engine.beginTrial()
        case .fixation:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.currentSpec.fixationMs)) {
                guard engine.phase == .fixation else { return }
                engine.showStimulus()
            }
        case .feedback:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(220)) {
                engine.advanceToNext()
                if engine.isComplete {
                    appModel.finalizeChoiceRTIfComplete()
                } else {
                    schedulePhase(engine)
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

    private func resultView(metrics: ChoiceRTMetrics) -> some View {
        BDResultPanel(title: "选择反应时完成", accent: BDColor.choiceRTAccent) {
            Text("查看本轮选择反应速度")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(BDColor.choiceRTAccent)

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
                .buttonStyle(BDSecondaryButton(accent: BDColor.choiceRTAccent))
        }
    }

    // feedbackText removed
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
