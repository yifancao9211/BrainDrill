import SwiftUI

struct DigitSpanTrainingView: View {
    @Environment(AppModel.self) private var appModel

    private var coordinator: DigitSpanCoordinator { appModel.digitSpan }

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
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 48))
                .foregroundStyle(BDColor.digitSpanAccent.opacity(0.6))
            Text("数字广度训练")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text("记住数字序列，然后按顺序复述")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
            Text("核心指标：最大广度 (Span)")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

            Picker("模式", selection: $selectedMode) {
                ForEach(DigitSpanMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)

            Button {
                userInput = []
                appModel.startDigitSpanSession(mode: selectedMode)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("开始训练")
                }
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 40).padding(.vertical, 16)
                .background(Capsule().fill(BDColor.digitSpanAccent))
            }
            .buttonStyle(.plain)
        }
    }

    private func activeView(engine: DigitSpanEngine) -> some View {
        VStack(spacing: 24) {
            Text("广度 \(engine.currentLength)  •  第 \(engine.trialIndex + 1) 轮")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

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

            ProgressView(value: engine.completionFraction)
                .tint(BDColor.digitSpanAccent)
                .frame(maxWidth: 300)

            Button("取消") { appModel.cancelDigitSpanSession() }
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(BDColor.error)
                .buttonStyle(.plain)
        }
    }

    private func presentingView(engine: DigitSpanEngine) -> some View {
        VStack(spacing: 16) {
            Text("记住这些数字")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)

            if let trial = engine.currentTrial, engine.presentingDigitIndex < trial.length {
                Text("\(trial.sequence[engine.presentingDigitIndex])")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(BDColor.digitSpanAccent)
                    .id("digit-\(engine.presentingDigitIndex)")
                    .transition(.scale.combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.2), value: engine.presentingDigitIndex)
                    .onAppear {
                        scheduleDigitAdvance(engine: engine)
                    }
            }
        }
    }

    private func scheduleDigitAdvance(engine: DigitSpanEngine) {
        let ms = engine.config.presentationMs
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(ms)) {
            guard engine.phase == .presenting else { return }
            if !engine.advancePresentingDigit() {
                engine.finishPresenting()
                userInput = []
            }
        }
    }

    private func recallingView(engine: DigitSpanEngine) -> some View {
        VStack(spacing: 16) {
            Text(engine.config.mode == .forward ? "请正序输入" : "请倒序输入")
                .font(.system(.body, design: .rounded))
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

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(0..<10, id: \.self) { digit in
                    Button {
                        userInput.append(digit)
                    } label: {
                        Text("\(digit)")
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                            .frame(width: 52, height: 52)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(BDColor.tileDefault))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 300)

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
                .buttonStyle(.plain)
                .disabled(userInput.isEmpty)

                Button {
                    _ = coordinator.submitResponse(userInput)
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
                .buttonStyle(.plain)
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

            Button("继续") {
                userInput = []
                if let result = coordinator.advanceAfterFeedback() {
                    appModel.recordDigitSpanResult(result)
                }
            }
            .font(.system(.callout, design: .rounded, weight: .semibold))
            .buttonStyle(.bordered)
        }
    }

    private func resultView(metrics: DigitSpanMetrics) -> some View {
        VStack(spacing: 20) {
            Text("数字广度完成")
                .font(.system(.title2, design: .rounded, weight: .bold))
            HStack(spacing: 16) {
                DSResultCard(label: "最大广度", value: "\(max(metrics.maxSpanForward, metrics.maxSpanBackward))", color: BDColor.digitSpanAccent)
                DSResultCard(label: "正确率", value: "\(Int(metrics.accuracy * 100))%", color: BDColor.green)
                DSResultCard(label: "位置错误", value: "\(metrics.positionErrors)", color: BDColor.warm)
            }
            .frame(maxWidth: 400)

            Button("关闭") { appModel.dismissDigitSpanResult() }
                .buttonStyle(.bordered)
        }
    }
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
