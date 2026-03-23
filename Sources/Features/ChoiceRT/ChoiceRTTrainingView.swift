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
            Text("看到颜色后，快速按对应按键（键盘 1/2/3/4）")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
            Text("核心指标：中位反应时 (RT)")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
            if appModel.settings.adaptiveDifficultyEnabled {
                Text("当前推荐档位 L\(appModel.adaptiveState(for: .choiceRT).recommendedStartLevel) · 每局 2 个 block")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(BDColor.textSecondary)
            }

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
            VStack(spacing: 8) {
                Text("试次 \(engine.currentTrialIndex + 1)/\(engine.trials.count)")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)
                Text("L\(engine.currentLevel) · Block \(engine.currentBlock + 1)/\(engine.totalBlocks)")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)

                BDFeedbackNote(text: feedbackText(engine), color: BDColor.choiceRTAccent)
            }

            BDTrainingStage(accent: BDColor.choiceRTAccent) {
                phaseContent(engine: engine)
                    .frame(height: 150)
            }

            let canRespond = engine.phase == .stimulus
            HStack(spacing: 12) {
                ForEach(0..<engine.currentSpec.choiceCount, id: \.self) { i in
                    let keyboardKeys: [KeyEquivalent] = ["1", "2", "3", "4"]
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
                    .disabled(!canRespond)
                    .keyboardShortcut(i < keyboardKeys.count ? keyboardKeys[i] : "0", modifiers: [])
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
        .onAppear { schedulePhase(engine) }
        .onChange(of: engine.phase) { _, _ in schedulePhase(engine) }
    }

    @ViewBuilder
    private func phaseContent(engine: ChoiceRTEngine) -> some View {
        switch engine.phase {
        case .fixation:
            Text("+")
                .font(.system(size: 64, weight: .light, design: .rounded))
                .foregroundStyle(.secondary)
        case .stimulus:
            if let trial = engine.currentTrial {
                Circle()
                    .fill(stimulusColors[trial.stimulus.colorIndex])
                    .frame(width: 100, height: 100)
            }
        case .feedback(let correct):
            VStack(spacing: 8) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(correct ? BDColor.green : BDColor.error)
                Text(correct ? "按键映射正确" : "颜色与按键映射不匹配")
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)
            }
        default:
            Color.clear.frame(height: 1)
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

    private func feedbackText(_ engine: ChoiceRTEngine) -> String {
        switch engine.phase {
        case .fixation:
            return "注视中央，等待颜色出现"
        case .stimulus:
            if let trial = engine.currentTrial {
                return "看到 \(trial.stimulus.label) 后按键 \(trial.correctResponseIndex + 1)"
            }
            return coordinator.statusMessage
        case .feedback(let correct):
            return correct ? "响应正确" : "重新确认颜色和按键编号"
        case let .blockBreak(_, outcome, nextLevel):
            switch outcome {
            case .promote:
                return "进入更高映射负荷 L\(nextLevel)"
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
