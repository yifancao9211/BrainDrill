import SwiftUI

struct DigitSpanTrainingView: View {
    @Environment(AppModel.self) private var appModel

    private var coordinator: DigitSpanCoordinator { appModel.digitSpan }
    private let feedbackDelayMs = 450

    @State private var userInput: [Int] = []
    @State private var selectedMode: DigitSpanMode = .forward

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            if let engine = coordinator.engine, !engine.isComplete {
                activeView(engine: engine)
            } else if let result = coordinator.lastResult, let m = result.digitSpanMetrics {
                resultView(metrics: m)
            } else {
                idleView
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var idleView: some View {
        SurfaceCard(title: "数字广度训练", subtitle: "在统一训练壳层中完成数字编码、复述和结果回看。", accent: BDColor.digitSpanAccent) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    InfoPill(title: "起始广度 \(appModel.settings.digitSpanStartingLength)", accent: BDColor.digitSpanAccent)
                    InfoPill(title: "核心指标 Span", accent: BDColor.green)
                }

                BDInsightCard(
                    title: "训练说明",
                    bodyText: "正序更看保持，倒序更看操作更新。先稳定正确率，再尝试抬高广度。",
                    accent: BDColor.digitSpanAccent
                )

                Picker("模式", selection: $selectedMode) {
                    ForEach(DigitSpanMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)

                Text("连续答对 2 轮升一级，连续答错 2 轮结束本局。")
                    .font(.system(.caption))
                    .foregroundStyle(BDColor.textSecondary)

                Button("开始训练") {
                    userInput = []
                    appModel.startDigitSpanSession(mode: selectedMode)
                }
                .buttonStyle(BDPrimaryButton(accent: BDColor.digitSpanAccent))
            }
        }
    }

    private func activeView(engine: DigitSpanEngine) -> some View {
        BDTrainingShell(accent: BDColor.digitSpanAccent) {
            VStack(spacing: 8) {
                Text("广度 \(engine.currentLength)  •  第 \(engine.trialIndex + 1) 轮")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(phaseTitle(for: engine))
                    .font(.system(.title3, design: .rounded, weight: .semibold))

                Text(phaseSubtitle(for: engine))
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        } stage: {
            switch engine.phase {
            case .presenting:
                presentingView(engine: engine)
            case .recalling:
                recallingView(engine: engine)
            case .feedback(let correct):
                feedbackView(correct: correct, engine: engine)
            default:
                EmptyView()
            }
        } footer: {
            VStack(spacing: 16) {
                staircaseStatus(engine: engine)

                Button("取消") { appModel.cancelDigitSpanSession() }
                    .buttonStyle(BDSecondaryButton(accent: BDColor.error))
            }
        }
    }

    private func presentingView(engine: DigitSpanEngine) -> some View {
        VStack(spacing: 16) {
            if let trial = engine.currentTrial, engine.presentingDigitIndex < trial.length {
                Text("\(trial.sequence[engine.presentingDigitIndex])")
                    .font(.system(size: 84, weight: .bold, design: .rounded))
                    .foregroundStyle(BDColor.digitSpanAccent)
                    .frame(width: 140, height: 140)
                    .background(
                        Color.clear.bdPanelSurface(.primary, cornerRadius: 40)
                            .shadow(color: BDColor.digitSpanAccent.opacity(0.2), radius: 24, y: 12)
                    )
                    .id("digit-\(engine.presentingDigitIndex)")
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: engine.presentingDigitIndex)
            } else {
                Color.clear.frame(width: 140, height: 140)
            }
        }
        .task(id: presentationTaskID(for: engine)) {
            await scheduleDigitAdvance(engine: engine)
        }
    }

    private func scheduleDigitAdvance(engine: DigitSpanEngine) async {
        let ms = engine.config.presentationMs
        try? await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)
        guard engine.phase == .presenting else { return }
        if !engine.advancePresentingDigit() {
            engine.finishPresenting()
            userInput = []
        }
    }

    private func recallingView(engine: DigitSpanEngine) -> some View {
        VStack(spacing: 16) {
            Text(engine.config.mode == .forward ? "请正序输入" : "请倒序输入")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)

            Text("已输入 \(userInput.count)/\(targetInputCount(for: engine))")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if userInput.isEmpty {
                    Text("点击数字键输入")
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(Array(userInput.enumerated()), id: \.offset) { _, digit in
                        Text("\(digit)")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(BDColor.digitSpanAccent)
                    }
                }
            }
            .frame(minHeight: 40)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(64), spacing: 14), count: 5), spacing: 14) {
                ForEach(0..<10, id: \.self) { digit in
                    Button {
                        appendDigit(digit, engine: engine)
                    } label: {
                        Text("\(digit)")
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(BDColor.digitSpanAccent)
                            .frame(width: 64, height: 64)
                            .background(Color.clear.bdPanelSurface(.primary, cornerRadius: 18))
                    }
                    .buttonStyle(BDSpringPressStyle())
                    .disabled(userInput.count >= targetInputCount(for: engine))
                }
            }
            .padding(.vertical, 16)

            HStack(spacing: 16) {
                Button {
                    if !userInput.isEmpty { userInput.removeLast() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "delete.left")
                        Text("删除")
                    }
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Capsule().fill(BDColor.error.opacity(0.12)))
                    .foregroundStyle(BDColor.error)
                }
                .buttonStyle(BDSecondaryButton(accent: BDColor.error))
                .disabled(userInput.isEmpty)

                Button {
                    submitResponse(engine: engine)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                        Text("确认")
                    }
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Capsule().fill(BDColor.digitSpanAccent))
                }
                .buttonStyle(BDPrimaryButton(accent: BDColor.digitSpanAccent))
                .disabled(userInput.isEmpty)
            }
        }
    }

    private func feedbackView(correct: Bool, engine: DigitSpanEngine) -> some View {
        VStack(spacing: 16) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(correct ? BDColor.green : BDColor.error)

            Text(correct ? "正确！" : "错误")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(correct ? BDColor.green : BDColor.error)

            if !correct, let trial = engine.results.last {
                let expected = engine.config.mode == .forward
                    ? trial.sequence
                    : trial.sequence.reversed()
                Text("正确答案：\(expected.map(String.init).joined(separator: " "))")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text("将自动进入下一轮")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

            Button("继续") {
                advanceAfterFeedback()
            }
            .font(.system(.callout, design: .rounded, weight: .semibold))
            .buttonStyle(BDSecondaryButton(accent: correct ? BDColor.green : BDColor.error))
        }
        .task(id: feedbackTaskID(for: engine, correct: correct)) {
            await scheduleAutoAdvanceAfterFeedback(engine: engine, correct: correct)
        }
    }

    private func resultView(metrics: DigitSpanMetrics) -> some View {
        BDResultPanel(title: "数字广度完成", accent: BDColor.digitSpanAccent) {
            Text("查看本轮数字工作记忆表现")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(BDColor.digitSpanAccent)

            HStack(spacing: 16) {
                DSResultCard(label: "最大广度", value: "\(max(metrics.maxSpanForward, metrics.maxSpanBackward))", color: BDColor.digitSpanAccent)
                DSResultCard(label: "正确率", value: "\(Int(metrics.accuracy * 100))%", color: BDColor.green)
                DSResultCard(label: "位置错误", value: "\(metrics.positionErrors)", color: BDColor.warm)
            }
            .frame(maxWidth: 400)

            if appModel.settings.adaptiveDifficultyEnabled {
                Text("下次训练将从广度 \(appModel.settings.digitSpanStartingLength) 开始。")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(BDColor.textSecondary)
            }

            Button("关闭") { appModel.dismissDigitSpanResult() }
                .buttonStyle(BDSecondaryButton(accent: BDColor.digitSpanAccent))
        }
    }

    private func staircaseStatus(engine: DigitSpanEngine) -> some View {
        HStack(spacing: 12) {
            staircaseBadge(
                title: "升级进度",
                value: "\(engine.consecutiveCorrectCount)/\(engine.advanceThreshold)",
                color: BDColor.green
            )
            staircaseBadge(
                title: "结束计数",
                value: "\(engine.consecutiveWrongCount)/\(engine.endThreshold)",
                color: BDColor.error
            )
        }
    }

    private func appendDigit(_ digit: Int, engine: DigitSpanEngine) {
        guard engine.phase == .recalling else { return }
        let targetCount = targetInputCount(for: engine)
        guard userInput.count < targetCount else { return }
        userInput.append(digit)
        if userInput.count == targetCount {
            submitResponse(engine: engine)
        }
    }

    private func submitResponse(engine: DigitSpanEngine) {
        guard engine.phase == .recalling, !userInput.isEmpty else { return }
        _ = coordinator.submitResponse(userInput)
    }

    private func advanceAfterFeedback() {
        userInput = []
        if let result = coordinator.advanceAfterFeedback() {
            appModel.recordDigitSpanResult(result)
        }
    }

    private func scheduleAutoAdvanceAfterFeedback(engine: DigitSpanEngine, correct: Bool) async {
        let trialIndex = engine.trialIndex
        try? await Task.sleep(nanoseconds: UInt64(feedbackDelayMs) * 1_000_000)
        guard engine.phase == .feedback(correct: correct), engine.trialIndex == trialIndex else { return }
        advanceAfterFeedback()
    }

    private func targetInputCount(for engine: DigitSpanEngine) -> Int {
        engine.currentTrial?.length ?? engine.currentLength
    }

    private func presentationTaskID(for engine: DigitSpanEngine) -> String {
        "digit-present-\(engine.trialIndex)-\(engine.presentingDigitIndex)-\(engine.currentTrial?.id ?? -1)"
    }

    private func feedbackTaskID(for engine: DigitSpanEngine, correct: Bool) -> String {
        "digit-feedback-\(engine.trialIndex)-\(correct)"
    }

    private func phaseTitle(for engine: DigitSpanEngine) -> String {
        switch engine.phase {
        case .presenting:
            "记住序列"
        case .recalling:
            "开始复述"
        case .feedback(let correct):
            correct ? "回答正确" : "回答错误"
        default:
            ""
        }
    }

    private func phaseSubtitle(for engine: DigitSpanEngine) -> String {
        switch engine.phase {
        case .presenting:
            "数字会自动逐个展示"
        case .recalling:
            engine.config.mode == .forward ? "按原顺序输入数字" : "按倒序输入数字"
        case .feedback(let correct):
            correct ? "保持节奏，马上进入下一轮" : "查看答案后会自动继续"
        default:
            ""
        }
    }
}

@MainActor
private func staircaseBadge(title: String, value: String, color: Color) -> some View {
    VStack(spacing: 4) {
        Text(title)
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .foregroundStyle(BDColor.textSecondary)
        Text(value)
            .font(.system(.callout, design: .rounded, weight: .bold))
            .foregroundStyle(color)
            .monospacedDigit()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .bdPanelSurface(.secondary, cornerRadius: 14)
}

private struct DSResultCard: View {
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
