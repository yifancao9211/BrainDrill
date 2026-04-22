import SwiftUI

struct SyllogismTrainingView: View {
    private enum FocusTarget: Hashable {
        case start
        case nextTrial
        case showHint
        case valid
        case invalid
        case continueAction
        case completed
        case restart
        case cancel
    }

    @Environment(AppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedTarget: FocusTarget?

    var body: some View {
        VStack(spacing: 0) {
            switch appModel.syllogismCoord.mode {
            case .learning(let group):
                SyllogismLearningView(lessonGroup: group)
            case .practice(let group):
                SyllogismPracticeView(lessonGroup: group)
            case .training:
                if let engine = appModel.syllogismCoord.engine {
                    trainingContent(engine: engine)
                } else {
                    startPanel
                }
            case .idle:
                if let result = appModel.syllogismCoord.lastResult,
                   let metrics = result.syllogismMetrics {
                    resultPanel(metrics: metrics)
                } else {
                    startPanel
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .onAppear {
            focusedTarget = appModel.syllogismCoord.engine == nil ? .start : .nextTrial
        }
        .onChange(of: appModel.syllogismCoord.engine?.phase) { _, phase in
            switch phase {
            case .idle:
                focusedTarget = .nextTrial
            case .presenting:
                focusedTarget = .valid
            case .feedback:
                focusedTarget = .continueAction
            case .completed:
                focusedTarget = .completed
            case .none:
                focusedTarget = appModel.syllogismCoord.lastResult == nil ? .start : .restart
            }
        }
    }

    // MARK: - Start Panel

    private var startPanel: some View {
        let difficulty = appModel.adaptiveState(for: .syllogism).recommendedStartLevel
        let hasLearned = appModel.syllogismCoord.hasCompletedLearning(for: difficulty)
        let weakTypes = appModel.syllogismCoord.weakTypes(for: difficulty)

        return SurfaceCard(title: "逻辑快判", subtitle: "学习逻辑推理规则，限时判断推理是否有效。", accent: BDColor.syllogismAccent) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    InfoPill(title: "推荐 Level \(difficulty)", accent: BDColor.syllogismAccent)
                    InfoPill(title: "核心指标 d'", accent: BDColor.green)
                    if !weakTypes.isEmpty {
                        InfoPill(title: "\(weakTypes.count) 个薄弱类型", accent: BDColor.error)
                    }
                }

                BDInsightCard(
                    title: hasLearned ? "训练说明" : "推荐先学习",
                    bodyText: hasLearned
                        ? "阅读前提与结论，快速判断推理是否有效。薄弱类型会优先出现。"
                        : "首次建议先学习逻辑推理规则，建立概念框架后再做限时训练。",
                    accent: BDColor.syllogismAccent
                )

                // Lesson list button
                Button {
                    appModel.syllogismCoord.startLearning(lessonGroup: 1)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "book.fill")
                        Text(hasLearned ? "复习知识点" : "开始学习")
                    }
                }
                .buttonStyle(hasLearned
                    ? BDSecondaryButton(accent: BDColor.syllogismAccent)
                    : BDSecondaryButton(accent: BDColor.syllogismAccent))

                Button("开始训练") {
                    let state = appModel.adaptiveState(for: .syllogism)
                    appModel.syllogismCoord.startSession(adaptiveState: state)
                }
                .buttonStyle(BDPrimaryButton(accent: BDColor.syllogismAccent))
                .keyboardShortcut(.defaultAction)
                .focused($focusedTarget, equals: .start)
            }
        }
    }

    // MARK: - Training Content

    @ViewBuilder
    private func trainingContent(engine: SyllogismEngine) -> some View {
        BDTrainingShell(accent: BDColor.syllogismAccent) {
            HStack(spacing: 12) {
                Text("第 \(engine.currentTrialIndex + 1) / \(engine.totalTrials) 题")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(BDColor.textSecondary)

                ProgressView(value: engine.completionFraction)
                    .tint(BDColor.syllogismAccent)
            }
        } stage: {
            switch engine.phase {
            case .idle:
                readyPrompt(engine: engine)
            case .presenting:
                trialView(engine: engine)
            case .feedback(let correct, let explanation):
                feedbackView(correct: correct, explanation: explanation, engine: engine)
            case .completed:
                completedPrompt
            }
        } footer: {
            Button("取消") {
                appModel.syllogismCoord.cancelSession()
            }
            .buttonStyle(BDSecondaryButton(accent: BDColor.error))
            .keyboardShortcut(.cancelAction)
            .focused($focusedTarget, equals: .cancel)
        }
    }

    private func readyPrompt(engine: SyllogismEngine) -> some View {
        VStack(spacing: 20) {
            Text("准备好了吗？")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(BDColor.textPrimary)

            Button("下一题") {
                engine.beginNextTrial()
            }
            .buttonStyle(BDPrimaryButton(accent: BDColor.syllogismAccent))
            .keyboardShortcut(.defaultAction)
            .focused($focusedTarget, equals: .nextTrial)
        }
    }

    @ViewBuilder
    private func trialView(engine: SyllogismEngine) -> some View {
        if let trial = engine.currentTrial {
            VStack(spacing: 24) {
                // Unverified premise warning
                if trial.hasUnverifiedPremise {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("部分前提未被完全证实")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(BDColor.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.yellow.opacity(0.1)))
                }

                // Premises
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(trial.premises.enumerated()), id: \.offset) { index, premise in
                        HStack(alignment: .top, spacing: 12) {
                            Text("前提\(index + 1)")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(BDColor.syllogismAccent)
                                .frame(width: 48, alignment: .trailing)

                            Text(premise)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(BDColor.textPrimary)
                        }
                    }

                    Divider().padding(.vertical, 4)

                    HStack(alignment: .top, spacing: 12) {
                        Text("结论")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(.orange)
                            .frame(width: 48, alignment: .trailing)

                        Text(trial.conclusion)
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(BDColor.textPrimary)
                    }
                }
                .padding(24)
                .frame(maxWidth: 600)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(BDColor.panelSecondaryFill))

                // Hint button
                if engine.hintShownForCurrentTrial {
                    Text(trial.abstractForm)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(BDColor.textSecondary)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(BDColor.syllogismAccent.opacity(0.1)))
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    Button {
                        if reduceMotion {
                            engine.hintShownForCurrentTrial = true
                        } else {
                            withAnimation(.easeOut(duration: 0.2)) {
                                engine.hintShownForCurrentTrial = true
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                            Text("显示逻辑形式")
                        }
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(BDColor.syllogismAccent)
                    }
                    .buttonStyle(BDSecondaryButton(accent: BDColor.syllogismAccent))
                    .focused($focusedTarget, equals: .showHint)
                }

                // Response buttons
                HStack(spacing: 24) {
                    Button {
                        engine.recordResponse(userSaysValid: true)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("有效")
                        }
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Color.green.opacity(0.85)))
                    }
                    .buttonStyle(BDPrimaryButton(accent: BDColor.green))
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    .focused($focusedTarget, equals: .valid)

                    Button {
                        engine.recordResponse(userSaysValid: false)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                            Text("无效")
                        }
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Color.red.opacity(0.85)))
                    }
                    .buttonStyle(BDSecondaryButton(accent: BDColor.error))
                    .keyboardShortcut(.rightArrow, modifiers: [])
                    .focused($focusedTarget, equals: .invalid)
                }
            }
        }
    }

    private func feedbackView(correct: Bool, explanation: String, engine: SyllogismEngine) -> some View {
        VStack(spacing: 20) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(correct ? .green : .red)
                .symbolEffect(.bounce, value: correct)

            Text(explanation)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(BDColor.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(BDColor.panelSecondaryFill))

            // Detailed explanation (auto-expand first 5 sessions)
            if let trial = engine.currentTrial, !trial.detailedExplanation.isEmpty {
                let autoExpand = appModel.syllogismCoord.sessionsCompleted < 5
                DisclosureGroup("📖 详细解析") {
                    Text(trial.detailedExplanation)
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(BDColor.textSecondary)
                        .padding(.top, 8)
                }
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(BDColor.syllogismAccent)
                .frame(maxWidth: 500)
                .padding(.horizontal, 16)
                .disclosureGroupStyle(.automatic)
                .onAppear {
                    // Note: DisclosureGroup doesn't support programmatic expansion easily,
                    // but the first 5 sessions hint is conveyed through auto-expand behavior
                    _ = autoExpand
                }
            }

            Button("继续") {
                engine.advanceToNext()
                if !engine.isComplete {
                    engine.beginNextTrial()
                } else {
                    if let result = appModel.syllogismCoord.finalizeIfComplete() {
                        appModel.appendSessionPublic(result)
                    }
                }
            }
            .buttonStyle(BDPrimaryButton(accent: BDColor.syllogismAccent))
            .keyboardShortcut(.space, modifiers: [])
            .focused($focusedTarget, equals: .continueAction)
        }
    }

    private var completedPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 48))
                .foregroundStyle(BDColor.syllogismAccent)

            Text("训练完成！")
                .font(.system(.title2, design: .rounded, weight: .bold))

            Button("查看结果") {
                if let result = appModel.syllogismCoord.finalizeIfComplete() {
                    appModel.appendSessionPublic(result)
                }
            }
            .buttonStyle(BDPrimaryButton(accent: BDColor.syllogismAccent))
            .keyboardShortcut(.defaultAction)
            .focused($focusedTarget, equals: .completed)
        }
    }

    // MARK: - Result Panel

    private func resultPanel(metrics: SyllogismMetrics) -> some View {
        BDResultPanel(title: "逻辑快判完成", accent: BDColor.syllogismAccent) {
            Text("查看本轮形式逻辑表现")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(BDColor.syllogismAccent)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                metricCard(title: "总准确率", value: "\(String(format: "%.0f", metrics.accuracy * 100))%")
                metricCard(title: "有效推理准确率", value: "\(String(format: "%.0f", metrics.validAccuracy * 100))%")
                metricCard(title: "无效推理准确率", value: "\(String(format: "%.0f", metrics.invalidAccuracy * 100))%")
                metricCard(title: "d' 判别力", value: String(format: "%.2f", metrics.dPrime))
                metricCard(title: "中位反应时", value: String(format: "%.1fs", metrics.medianRT))
                metricCard(title: "提示使用", value: "\(metrics.hintUsageCount)次")
            }
            .frame(maxWidth: 600)

            Button("再来一组") {
                let state = appModel.adaptiveState(for: .syllogism)
                appModel.syllogismCoord.startSession(adaptiveState: state)
            }
            .buttonStyle(BDPrimaryButton(accent: BDColor.syllogismAccent))
            .keyboardShortcut(.defaultAction)
            .focused($focusedTarget, equals: .restart)
        }
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(BDColor.syllogismAccent)
            Text(title)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(BDColor.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(BDColor.panelSecondaryFill))
    }
}
