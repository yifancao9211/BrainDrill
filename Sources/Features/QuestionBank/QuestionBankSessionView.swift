import SwiftUI

/// 通用题库练习会话 UI：题干 → 选项作答 → 即时解析 → 下一题 → 结算。
/// 逻辑推理练习题与考公题库共用本视图，差异只在外部传入的 coordinator 与配色。
struct QuestionBankSessionView: View {
    @Environment(AppModel.self) private var appModel
    let coordinator: QuestionBankCoordinator
    let accent: Color
    /// 会话完成（答完最后一题或计时耗尽）时回调，由父级负责入库。
    let onFinalize: () -> Void

    @State private var remainingSeconds: Int = 0
    /// 当前题已揭示的提示步数（分步提示）。换题时归零。
    @State private var revealedHints: Int = 0
    /// 演草纸标记（行-列 → ✓/✗）。换题时清空。
    @State private var scratchMarks: [String: ScratchMark] = [:]

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let engine = coordinator.engine {
                BDTrainingShell(accent: accent) {
                    header(engine: engine)
                } stage: {
                    ScrollView {
                        stage(engine: engine)
                            .frame(maxWidth: 640)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                } footer: {
                    Button("结束练习") {
                        coordinator.cancelSession()
                    }
                    .buttonStyle(BDSecondaryButton(accent: BDColor.error))
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
        .onAppear {
            remainingSeconds = coordinator.engine?.totalSeconds ?? 0
        }
        .onReceive(ticker) { _ in
            guard let engine = coordinator.engine, engine.timed, !engine.isComplete else { return }
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                coordinator.forceComplete()
                onFinalize()
            }
        }
        .onChange(of: coordinator.engine?.index) { _, _ in
            revealedHints = 0
            scratchMarks = [:]
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func header(engine: QuestionBankEngine) -> some View {
        HStack(spacing: 12) {
            Text("第 \(min(engine.index + 1, engine.total)) / \(engine.total) 题")
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(BDColor.textSecondary)

            ProgressView(value: engine.completionFraction)
                .tint(accent)

            Text("正确 \(engine.correctSoFar)")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(accent)

            if engine.timed {
                Label(timeString(remainingSeconds), systemImage: "timer")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(remainingSeconds <= 30 ? BDColor.error : BDColor.textSecondary)
            }
        }
    }

    // MARK: - Stage

    @ViewBuilder
    private func stage(engine: QuestionBankEngine) -> some View {
        if let question = engine.currentQuestion {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    InfoPill(title: question.section.displayName, accent: accent)
                    InfoPill(title: question.type, accent: BDColor.textSecondary)
                    InfoPill(title: "难度 \(question.difficulty)", accent: BDColor.gold)
                }

                if let material = question.material, !material.isEmpty {
                    Text(material)
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(BDColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(BDColor.panelSecondaryFill))
                }

                Text(question.stem)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(BDColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let prompt = question.figurePrompt {
                    figurePromptRow(prompt)
                }

                if question.isFigureQuestion {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                            optionCard(index: index, option: option, engine: engine, question: question)
                        }
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                            optionCard(index: index, option: option, engine: engine, question: question)
                        }
                    }
                }

                if case .presenting = engine.phase {
                    hintArea(question: question)
                }

                if case let .feedback(selectedIndex, correct) = engine.phase {
                    feedback(correct: correct, selectedIndex: selectedIndex, question: question, engine: engine)
                }
            }
        }
    }

    private func optionCard(index: Int, option: String, engine: QuestionBankEngine, question: BankQuestion) -> some View {
        let letter = String(UnicodeScalar(65 + index)!)
        let state = optionState(index: index, engine: engine, question: question)

        return BDSelectionOptionCard(
            isSelected: state != .neutral,
            accent: state.accent(default: accent),
            action: {
                guard case .presenting = engine.phase else { return }
                coordinator.select(index)
            }
        ) {
            HStack(alignment: .top, spacing: 12) {
                Text(letter)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(state.accent(default: accent))
                    .frame(width: 24)
                if let figures = question.figureOptions, figures.indices.contains(index) {
                    FigureView(spec: figures[index], size: 48, color: state.accent(default: BDColor.textPrimary))
                        .frame(maxWidth: .infinity)
                } else {
                    Text(option)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(BDColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                if state == .correct {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(BDColor.green)
                } else if state == .wrong {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(BDColor.error)
                }
            }
        }
        .disabled({ if case .presenting = engine.phase { return false } else { return true } }())
        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [])
    }

    /// 图形推理题干：图形序列 + 末尾的「?」框。
    private func figurePromptRow(_ figures: [FigureSpec]) -> some View {
        HStack(spacing: 10) {
            ForEach(Array(figures.enumerated()), id: \.offset) { _, spec in
                FigureView(spec: spec, size: 52, color: BDColor.textPrimary)
                    .frame(width: 72, height: 72)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(BDColor.panelSecondaryFill))
            }
            Text("?")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .frame(width: 72, height: 72)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(accent.opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(accent.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [4])))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum OptionState {
        case neutral, correct, wrong
        func accent(default base: Color) -> Color {
            switch self {
            case .neutral: base
            case .correct: BDColor.green
            case .wrong:   BDColor.error
            }
        }
    }

    private func optionState(index: Int, engine: QuestionBankEngine, question: BankQuestion) -> OptionState {
        guard case let .feedback(selectedIndex, _) = engine.phase else { return .neutral }
        if index == question.answerIndex { return .correct }
        if index == selectedIndex { return .wrong }
        return .neutral
    }

    // MARK: - Hint (分步提示)

    @ViewBuilder
    private func hintArea(question: BankQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 演草纸：表格类逻辑题随时可展开，自己点 ✓/✗ 做排除。
            if let diagram = question.diagram {
                DisclosureGroup {
                    ScratchTableView(table: diagram, accent: accent, marks: $scratchMarks)
                        .padding(.top, 8)
                } label: {
                    Label("演草纸：在排除表上标 ✓/✗", systemImage: "squareshape.split.3x3")
                        .font(.system(.callout, design: .rounded, weight: .medium))
                        .foregroundStyle(accent)
                }
                .tint(accent)
            }

            if !question.steps.isEmpty {
                if revealedHints > 0 {
                    SolutionStepsView(steps: question.steps, accent: accent, revealedCount: revealedHints)
                }
                HStack(spacing: 12) {
                    Button {
                        revealedHints = min(revealedHints + 1, question.steps.count)
                    } label: {
                        Label(revealedHints == 0 ? "分步提示" : "下一步提示", systemImage: "lightbulb")
                    }
                    .buttonStyle(BDSecondaryButton(accent: accent))
                    .disabled(revealedHints >= question.steps.count)

                    if revealedHints > 0 {
                        Text("第 \(revealedHints)/\(question.steps.count) 步")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(BDColor.textSecondary)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func feedback(correct: Bool, selectedIndex: Int, question: BankQuestion, engine: QuestionBankEngine) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: correct ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .foregroundStyle(correct ? BDColor.green : BDColor.error)
                Text(correct ? "回答正确" : "回答错误 — 正确答案 \(String(UnicodeScalar(65 + question.answerIndex)!))")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(correct ? BDColor.green : BDColor.error)
            }

            Text(question.explanation)
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(BDColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !question.steps.isEmpty {
                Text("解题步骤")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(accent)
                SolutionStepsView(steps: question.steps, accent: accent, revealedCount: question.steps.count)
            } else if let diagram = question.diagram {
                DiagramTableView(table: diagram, accent: accent, scaffold: false)
            }

            Button(engine.index + 1 >= engine.total ? "查看结果" : "下一题") {
                coordinator.advance()
                if coordinator.engine?.isComplete ?? true {
                    onFinalize()
                }
            }
            .buttonStyle(BDPrimaryButton(accent: accent))
            .keyboardShortcut(.defaultAction)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(accent.opacity(0.06)))
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

/// 题库练习结算面板（逻辑推理 / 考公共用）。
struct QuestionBankResultView: View {
    @Environment(AppModel.self) private var appModel
    let metrics: BankPracticeMetrics
    let accent: Color
    let restartTitle: String
    let onRestart: () -> Void

    /// 一句"人话"诊断：满分鼓励 / 指出最弱题型 + 错题去向。
    private var insight: String {
        guard metrics.totalQuestions > 0 else { return "本组没有作答记录。" }
        if metrics.correctCount == metrics.totalQuestions {
            return "全部答对，状态极佳——下次系统会自动给你更难的题。"
        }
        let weakest = metrics.perTypeTotal.compactMap { type, total -> (String, Double)? in
            guard total > 0 else { return nil }
            return (type, Double(metrics.perTypeCorrect[type] ?? 0) / Double(total))
        }.min { $0.1 < $1.1 }
        if let w = weakest, w.1 < 1 {
            return "最弱题型：\(w.0)（正确率 \(Int(w.1 * 100))%）。做错的题已进错题本，按遗忘曲线安排复习，建议下次重点补这一类。"
        }
        return "整体稳定，继续保持节奏。错题已收进错题本待复习。"
    }

    var body: some View {
        BDResultPanel(title: "\(metrics.section.displayName)练习完成", accent: accent) {
            Text("正确率 \(Int(metrics.accuracy * 100))%")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(accent)

            BDInsightCard(title: "本组小结", bodyText: insight, accent: accent)
                .frame(maxWidth: 560)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                BDResultMetricCard(label: "题数", value: "\(metrics.totalQuestions)", color: accent)
                BDResultMetricCard(label: "答对", value: "\(metrics.correctCount)", color: BDColor.green)
                BDResultMetricCard(label: "正确率", value: "\(Int(metrics.accuracy * 100))%", color: accent)
                BDResultMetricCard(label: "中位用时", value: String(format: "%.1fs", metrics.medianRT), color: BDColor.gold)
                BDResultMetricCard(label: "难度", value: "\(metrics.difficulty)", color: BDColor.textSecondary)
                BDResultMetricCard(label: "模式", value: metrics.timed ? "模考" : "练习", color: BDColor.textSecondary)
            }
            .frame(maxWidth: 560)

            if !metrics.perTypeTotal.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("题型表现")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(BDColor.textSecondary)
                    ForEach(metrics.perTypeTotal.keys.sorted(), id: \.self) { type in
                        let total = metrics.perTypeTotal[type] ?? 0
                        let correct = metrics.perTypeCorrect[type] ?? 0
                        HStack {
                            Text(type).font(.system(.caption, design: .rounded))
                            Spacer()
                            Text("\(correct)/\(total)")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(correct == total ? BDColor.green : BDColor.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: 560, alignment: .leading)
            }

            Button(restartTitle, action: onRestart)
                .buttonStyle(BDPrimaryButton(accent: accent))
                .keyboardShortcut(.defaultAction)
        }
    }
}
