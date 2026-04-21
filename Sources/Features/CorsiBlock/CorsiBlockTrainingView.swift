import SwiftUI

struct CorsiBlockTrainingView: View {
    @Environment(AppModel.self) private var appModel

    private var coordinator: CorsiBlockCoordinator { appModel.corsiBlock }
    private let feedbackDelayMs = 450

    @State private var userInput: [Int] = []
    @State private var selectedMode: CorsiBlockMode = .forward

    private let gridSize = 9
    private let columns = 3

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            if let engine = coordinator.engine, !engine.isComplete {
                activeView(engine: engine)
            } else if let result = coordinator.lastResult, let m = result.corsiBlockMetrics {
                resultView(metrics: m)
            } else {
                idleView
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var idleView: some View {
        SurfaceCard(title: "空间广度训练", subtitle: "在统一训练壳层中完成空间编码、复现和结果回看。", accent: BDColor.corsiBlockAccent) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    InfoPill(title: "起始广度 \(appModel.settings.corsiBlockStartingLength)", accent: BDColor.corsiBlockAccent)
                    InfoPill(title: "核心指标 Span", accent: BDColor.green)
                }

                BDInsightCard(
                    title: "训练说明",
                    bodyText: "先稳定编码空间序列，再完成正序或倒序复现。优先保证正确率，再看广度是否抬升。",
                    accent: BDColor.corsiBlockAccent
                )

                Picker("模式", selection: $selectedMode) {
                    ForEach(CorsiBlockMode.allCases) { mode in
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
                    appModel.startCorsiBlockSession(mode: selectedMode)
                }
                .buttonStyle(BDPrimaryButton(accent: BDColor.corsiBlockAccent))
            }
        }
    }

    private func activeView(engine: CorsiBlockEngine) -> some View {
        BDTrainingShell(accent: BDColor.corsiBlockAccent) {
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
            VStack(spacing: 20) {
                blockGrid(engine: engine)

                switch engine.phase {
                case .presenting:
                    EmptyView()
                case .recalling:
                    recallingControls(engine: engine)
                case .feedback(let correct):
                    feedbackView(correct: correct, engine: engine)
                default:
                    EmptyView()
                }
            }
        } footer: {
            VStack(spacing: 16) {
                staircaseStatus(engine: engine)

                Button("取消") { appModel.cancelCorsiBlockSession() }
                    .buttonStyle(BDSecondaryButton(accent: BDColor.error))
            }
        }
    }

    private func blockGrid(engine: CorsiBlockEngine) -> some View {
        let size: CGFloat = 72
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(size), spacing: 14), count: columns), spacing: 14) {
            ForEach(0..<gridSize, id: \.self) { idx in
                let isHighlighted = engine.phase == .presenting
                    && engine.currentTrial?.sequence[safe: engine.presentingBlockIndex] == idx
                let isSelected = userInput.contains(idx)
                let feedbackOrder = feedbackOrderLabel(for: idx, engine: engine)

                Button {
                    selectBlock(idx, engine: engine)
                } label: {
                    ZStack {
                        Color.clear.bdPanelSurface(.primary, cornerRadius: 18)

                        if isHighlighted {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(BDColor.corsiBlockAccent)
                                .shadow(color: BDColor.corsiBlockAccent.opacity(0.6), radius: 10, y: 4)
                        } else if let _ = feedbackOrder {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(BDColor.error.opacity(0.85))
                        } else if isSelected {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(BDColor.corsiBlockAccent.opacity(0.4))
                        }
                    }
                    .frame(width: size, height: size)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHighlighted)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
                    .overlay(
                        blockOverlay(for: idx, isSelected: isSelected, feedbackOrder: feedbackOrder)
                    )
                }
                .buttonStyle(BDSpringPressStyle())
                .disabled(engine.phase != .recalling)
            }
        }
        .padding(24)
        .bdPanelSurface(.secondary, cornerRadius: 28)
        .task(id: presentationTaskID(for: engine)) {
            await scheduleBlockPresentation(engine: engine)
        }
    }

    private func staircaseStatus(engine: CorsiBlockEngine) -> some View {
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

    private func scheduleBlockPresentation(engine: CorsiBlockEngine) async {
        guard engine.phase == .presenting else { return }
        let ms = engine.config.presentationMs
        try? await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)
        guard engine.phase == .presenting else { return }
        if !engine.advancePresentingBlock() {
            engine.finishPresenting()
            userInput = []
        }
    }

    private func recallingControls(engine: CorsiBlockEngine) -> some View {
        VStack(spacing: 12) {
            Text("已选择 \(userInput.count)/\(targetInputCount(for: engine))")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button {
                    if !userInput.isEmpty { userInput.removeLast() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "delete.left")
                        Text("撤销")
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
                    .background(Capsule().fill(BDColor.corsiBlockAccent))
                }
                .buttonStyle(BDPrimaryButton(accent: BDColor.corsiBlockAccent))
                .disabled(userInput.isEmpty)
            }
        }
    }

    private func feedbackView(correct: Bool, engine: CorsiBlockEngine) -> some View {
        VStack(spacing: 12) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(correct ? BDColor.green : BDColor.error)

            Text(correct ? "正确！" : "错误")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(correct ? BDColor.green : BDColor.error)

            if !correct {
                Text("正确顺序已标注在方块上")
                    .font(.system(.callout, design: .rounded))
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

    private func resultView(metrics: CorsiBlockMetrics) -> some View {
        BDResultPanel(title: "空间广度完成", accent: BDColor.corsiBlockAccent) {
            Text("查看本轮空间工作记忆表现")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(BDColor.corsiBlockAccent)

            HStack(spacing: 16) {
                CBResultCard(label: "最大广度", value: "\(metrics.maxSpan)", color: BDColor.corsiBlockAccent)
                CBResultCard(label: "正确率", value: "\(Int(metrics.accuracy * 100))%", color: BDColor.green)
                CBResultCard(label: "位置错误", value: "\(metrics.positionErrors)", color: BDColor.warm)
            }
            .frame(maxWidth: 400)

            if appModel.settings.adaptiveDifficultyEnabled {
                Text("下次训练将从广度 \(appModel.settings.corsiBlockStartingLength) 开始。")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(BDColor.textSecondary)
            }

            Button("关闭") { appModel.dismissCorsiBlockResult() }
                .buttonStyle(BDSecondaryButton(accent: BDColor.corsiBlockAccent))
        }
    }

    @ViewBuilder
    private func blockOverlay(for idx: Int, isSelected: Bool, feedbackOrder: Int?) -> some View {
        if let feedbackOrder {
            Text("\(feedbackOrder)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        } else if isSelected, let selectedOrder = userInput.firstIndex(of: idx) {
            Text("\(selectedOrder + 1)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func feedbackOrderLabel(for idx: Int, engine: CorsiBlockEngine) -> Int? {
        guard case .feedback(let correct) = engine.phase, !correct,
              let expected = engine.currentTrial?.expectedResponse,
              let order = expected.firstIndex(of: idx) else {
            return nil
        }
        return order + 1
    }

    private func selectBlock(_ idx: Int, engine: CorsiBlockEngine) {
        guard engine.phase == .recalling, !userInput.contains(idx) else { return }
        let targetCount = targetInputCount(for: engine)
        guard userInput.count < targetCount else { return }
        userInput.append(idx)
        if userInput.count == targetCount {
            submitResponse(engine: engine)
        }
    }

    private func submitResponse(engine: CorsiBlockEngine) {
        guard engine.phase == .recalling, !userInput.isEmpty else { return }
        coordinator.submitResponse(userInput)
    }

    private func advanceAfterFeedback() {
        userInput = []
        if let result = coordinator.advanceAfterFeedback() {
            appModel.recordCorsiBlockResult(result)
        }
    }

    private func scheduleAutoAdvanceAfterFeedback(engine: CorsiBlockEngine, correct: Bool) async {
        let trialIndex = engine.trialIndex
        try? await Task.sleep(nanoseconds: UInt64(feedbackDelayMs) * 1_000_000)
        guard engine.phase == .feedback(correct: correct), engine.trialIndex == trialIndex else { return }
        advanceAfterFeedback()
    }

    private func targetInputCount(for engine: CorsiBlockEngine) -> Int {
        engine.currentTrial?.length ?? engine.currentLength
    }

    private func presentationTaskID(for engine: CorsiBlockEngine) -> String {
        "corsi-present-\(engine.trialIndex)-\(engine.presentingBlockIndex)-\(engine.currentTrial?.id ?? -1)"
    }

    private func feedbackTaskID(for engine: CorsiBlockEngine, correct: Bool) -> String {
        "corsi-feedback-\(engine.trialIndex)-\(correct)"
    }

    private func phaseTitle(for engine: CorsiBlockEngine) -> String {
        switch engine.phase {
        case .presenting:
            "记住位置"
        case .recalling:
            "开始点击"
        case .feedback(let correct):
            correct ? "回答正确" : "回答错误"
        default:
            ""
        }
    }

    private func phaseSubtitle(for engine: CorsiBlockEngine) -> String {
        switch engine.phase {
        case .presenting:
            "方块会自动按顺序高亮"
        case .recalling:
            engine.config.mode == .forward ? "按原顺序点击方块" : "按倒序点击方块"
        case .feedback(let correct):
            correct ? "保持节奏，马上进入下一轮" : "错误顺序会在方块上直接标出"
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct CBResultCard: View {
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
