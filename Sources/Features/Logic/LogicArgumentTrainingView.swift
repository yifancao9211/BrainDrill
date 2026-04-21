import SwiftUI

struct LogicArgumentTrainingView: View {
    private enum FocusTarget: Hashable {
        case start
        case readingContinue
        case structureSubmit
        case fallacySubmit
        case evaluationSubmit
        case restart
        case cancel
    }

    @Environment(AppModel.self) private var appModel
    @FocusState private var focusedTarget: FocusTarget?

    var body: some View {
        VStack(spacing: 0) {
            if let engine = appModel.logicArgumentCoord.engine {
                trainingContent(engine: engine)
            } else if let result = appModel.logicArgumentCoord.lastResult,
                      let metrics = result.logicArgumentMetrics {
                resultPanel(metrics: metrics)
            } else {
                startPanel
            }
        }
        .onAppear {
            focusedTarget = appModel.logicArgumentCoord.engine == nil ? .start : .readingContinue
        }
        .onChange(of: appModel.logicArgumentCoord.engine?.phase) { _, phase in
            switch phase {
            case .reading:
                focusedTarget = .readingContinue
            case .structureAnnotation:
                focusedTarget = .structureSubmit
            case .fallacyDetection:
                focusedTarget = .fallacySubmit
            case .argumentEvaluation:
                focusedTarget = .evaluationSubmit
            case .completed:
                focusedTarget = nil
            case .none:
                focusedTarget = appModel.logicArgumentCoord.lastResult == nil ? .start : .restart
            }
        }
    }

    // MARK: - Start Panel

    private var startPanel: some View {
        VStack {
            Spacer()

            SurfaceCard(title: "论证分析", subtitle: "阅读材料后依次完成结构标注、谬误侦测和论证评估。", accent: BDColor.logicArgumentAccent) {
                let difficulty = appModel.adaptiveState(for: .logicArgument).recommendedStartLevel
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        InfoPill(title: "Level \(difficulty)", accent: BDColor.logicArgumentAccent)
                        InfoPill(title: "四阶段流程", accent: BDColor.teal)
                    }

                    BDInsightCard(
                        title: "训练目标",
                        bodyText: "通过拆出论证结构、识别谬误和判断加强/削弱信息，提升批判性思维和论证分析能力。",
                        accent: BDColor.logicArgumentAccent
                    )

                    Button("开始训练") {
                        let state = appModel.adaptiveState(for: .logicArgument)
                        appModel.logicArgumentCoord.startSession(adaptiveState: state)
                    }
                    .buttonStyle(BDPrimaryButton(accent: BDColor.logicArgumentAccent))
                    .keyboardShortcut(.defaultAction)
                    .focused($focusedTarget, equals: .start)
                }
            }
            .frame(maxWidth: 780)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Training Content

    @ViewBuilder
    private func trainingContent(engine: LogicArgumentEngine) -> some View {
        BDTrainingShell(accent: BDColor.logicArgumentAccent) {
            phaseIndicator(engine: engine)
        } stage: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch engine.phase {
                    case .reading:
                        readingPhase(engine: engine)
                    case .structureAnnotation:
                        structureAnnotationPhase(engine: engine)
                    case .fallacyDetection:
                        fallacyDetectionPhase(engine: engine)
                    case .argumentEvaluation:
                        argumentEvaluationPhase(engine: engine)
                    case .completed:
                        completedView(engine: engine)
                    }
                }
                .padding(20)
            }
        } footer: {
            EmptyView()
        }
    }

    private func phaseIndicator(engine: LogicArgumentEngine) -> some View {
        HStack(spacing: 12) {
            let phases: [(String, Bool)] = [
                ("阅读", engine.phase == .reading),
                ("结构", engine.phase == .structureAnnotation),
                ("谬误", engine.phase == .fallacyDetection),
                ("评估", engine.phase == .argumentEvaluation || engine.phase == .completed),
            ]

            ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                HStack(spacing: 4) {
                    Circle()
                        .fill(phase.1 ? BDColor.logicArgumentAccent : BDColor.panelSecondaryFill)
                        .frame(width: 8, height: 8)
                    Text(phase.0)
                        .font(.system(.caption, design: .rounded, weight: phase.1 ? .bold : .regular))
                        .foregroundStyle(phase.1 ? BDColor.logicArgumentAccent : BDColor.textSecondary)
                }
            }

            Spacer()

            Button("取消") {
                appModel.logicArgumentCoord.cancelSession()
            }
            .buttonStyle(BDSecondaryButton(accent: BDColor.error))
            .keyboardShortcut(.cancelAction)
            .focused($focusedTarget, equals: .cancel)
        }
    }

    // MARK: - Phase: Reading

    private func readingPhase(engine: LogicArgumentEngine) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(engine.currentPhaseTitle)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(BDColor.textPrimary)

            Text(engine.currentPhaseSubtitle)
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(BDColor.textSecondary)

            Text(engine.passage.title)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(BDColor.logicArgumentAccent)

            Text(engine.passage.body)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(BDColor.textPrimary)
                .lineSpacing(6)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BDColor.panelSecondaryFill))

            HStack {
                Spacer()
                Button {
                    engine.beginAnnotation()
                } label: {
                    HStack(spacing: 8) {
                        Text("开始分析")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(BDPrimaryButton(accent: BDColor.logicArgumentAccent))
                .keyboardShortcut(.defaultAction)
                .focused($focusedTarget, equals: .readingContinue)
            }
        }
    }

    // MARK: - Phase: Structure Annotation

    private func structureAnnotationPhase(engine: LogicArgumentEngine) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(engine.currentPhaseTitle)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(BDColor.textPrimary)

            Text(engine.currentPhaseSubtitle)
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(BDColor.textSecondary)

            ForEach(engine.passage.argumentComponents) { component in
                VStack(alignment: .leading, spacing: 8) {
                    Text(component.text)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(BDColor.textPrimary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(BDColor.panelSecondaryFill))

                    HStack(spacing: 8) {
                        ForEach(ArgumentComponentRole.allCases) { role in
                            let selected = engine.componentSelections[component.id] == role
                            BDSelectionChip(title: role.label, isSelected: selected, accent: BDColor.logicArgumentAccent) {
                                engine.selectComponentRole(component.id, role: role)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            HStack {
                Spacer()
                Button {
                    engine.submitStructureAnnotation()
                } label: {
                    HStack(spacing: 8) {
                        Text("下一阶段：谬误侦测")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(BDPrimaryButton(accent: engine.canSubmitStructure ? BDColor.logicArgumentAccent : BDColor.textSecondary))
                .disabled(!engine.canSubmitStructure)
                .keyboardShortcut(.defaultAction)
                .focused($focusedTarget, equals: .structureSubmit)
            }
        }
    }

    // MARK: - Phase: Fallacy Detection

    private func fallacyDetectionPhase(engine: LogicArgumentEngine) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(engine.currentPhaseTitle)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(BDColor.textPrimary)

            Text(engine.currentPhaseSubtitle)
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(BDColor.textSecondary)

            ForEach(engine.passage.fallacyItems) { item in
                VStack(alignment: .leading, spacing: 12) {
                    Text(item.argumentText)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(BDColor.textPrimary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(BDColor.panelSecondaryFill))

                    let options = item.allOptions
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(options) { fallacy in
                            let selected = engine.fallacySelections[item.id] == fallacy
                            BDSelectionOptionCard(isSelected: selected, accent: BDColor.logicArgumentAccent) {
                                engine.selectFallacy(item.id, fallacy: fallacy)
                            } content: {
                                VStack(spacing: 4) {
                                    Text(fallacy.label)
                                        .font(.system(.callout, design: .rounded, weight: .semibold))
                                    Text(fallacy.description)
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(selected ? .white.opacity(0.8) : BDColor.textSecondary)
                                }
                                .foregroundStyle(selected ? .white : BDColor.textPrimary)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            HStack {
                Spacer()
                let nextLabel = engine.passage.requiresEvaluation ? "下一阶段：论证评估" : "提交"
                Button {
                    engine.submitFallacyDetection()
                    if engine.isComplete {
                        if let result = appModel.logicArgumentCoord.finalizeIfComplete() {
                            appModel.appendSessionPublic(result)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(nextLabel)
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(BDPrimaryButton(accent: engine.canSubmitFallacy ? BDColor.logicArgumentAccent : BDColor.textSecondary))
                .disabled(!engine.canSubmitFallacy)
                .keyboardShortcut(.defaultAction)
                .focused($focusedTarget, equals: .fallacySubmit)
            }
        }
    }

    // MARK: - Phase: Argument Evaluation

    private func argumentEvaluationPhase(engine: LogicArgumentEngine) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(engine.currentPhaseTitle)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(BDColor.textPrimary)

            Text(engine.currentPhaseSubtitle)
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(BDColor.textSecondary)

            if let eval = engine.passage.evaluationItems.first {
                // Hidden assumption
                VStack(alignment: .leading, spacing: 12) {
                    Text("该论证的隐含假设是什么？")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(BDColor.textPrimary)

                    ForEach(Array(eval.assumptionOptions.enumerated()), id: \.offset) { index, option in
                        let selected = engine.assumptionSelection == index
                        BDSelectionOptionCard(isSelected: selected, accent: BDColor.logicArgumentAccent) {
                            engine.selectAssumption(index)
                        } content: {
                            HStack(spacing: 12) {
                                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(selected ? BDColor.logicArgumentAccent : BDColor.textSecondary)
                                Text(option)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(BDColor.textPrimary)
                                Spacer()
                            }
                        }
                    }
                }

                Divider().padding(.vertical, 8)

                // Strengthen / Weaken / Irrelevant
                VStack(alignment: .leading, spacing: 12) {
                    Text("以下信息能加强、削弱还是无关？")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(BDColor.textPrimary)

                    ForEach(eval.modifierStatements) { modifier in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(modifier.text)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(BDColor.textPrimary)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 8).fill(BDColor.panelSecondaryFill))

                            HStack(spacing: 8) {
                                ForEach(ArgumentModifierType.allCases) { type in
                                    let selected = engine.modifierSelections[modifier.id] == type
                                    BDSelectionChip(title: type.label, isSelected: selected, accent: modifierColor(type)) {
                                        engine.selectModifierType(modifier.id, type: type)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button {
                    engine.submitArgumentEvaluation()
                    if let result = appModel.logicArgumentCoord.finalizeIfComplete() {
                        appModel.appendSessionPublic(result)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("提交判分")
                    }
                }
                .buttonStyle(BDPrimaryButton(accent: engine.canSubmitEvaluation ? BDColor.logicArgumentAccent : BDColor.textSecondary))
                .disabled(!engine.canSubmitEvaluation)
                .keyboardShortcut(.defaultAction)
                .focused($focusedTarget, equals: .evaluationSubmit)
            }
        }
    }

    // MARK: - Completed

    private func completedView(engine: LogicArgumentEngine) -> some View {
        VStack(spacing: 16) {
            Text("分析完成，正在生成结果...")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(BDColor.textPrimary)
                .onAppear {
                    if let result = appModel.logicArgumentCoord.finalizeIfComplete() {
                        appModel.appendSessionPublic(result)
                    }
                }
        }
    }

    // MARK: - Result Panel

    private func resultPanel(metrics: LogicArgumentMetrics) -> some View {
        BDResultPanel(title: "论证分析结果", accent: BDColor.logicArgumentAccent) {
            Text("综合得分 \(String(format: "%.0f", metrics.compositeScore * 100))%")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(BDColor.logicArgumentAccent)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                metricCard(title: "结构标注", value: "\(String(format: "%.0f", metrics.componentAccuracy * 100))%",
                           detail: "\(metrics.componentCorrect)/\(metrics.componentTotal)")
                metricCard(title: "谬误侦测", value: "\(String(format: "%.0f", metrics.fallacyAccuracy * 100))%",
                           detail: "\(metrics.fallacyCorrect)/\(metrics.fallacyTotal)")
                metricCard(title: "论证评估", value: metrics.assumptionCorrect ? "✓" : "✗",
                           detail: "修饰 \(metrics.modifierCorrect)/\(metrics.modifierTotal)")
            }
            .frame(maxWidth: 600)

            Button("再来一篇") {
                let state = appModel.adaptiveState(for: .logicArgument)
                appModel.logicArgumentCoord.startSession(adaptiveState: state)
            }
            .buttonStyle(BDPrimaryButton(accent: BDColor.logicArgumentAccent))
            .keyboardShortcut(.defaultAction)
            .focused($focusedTarget, equals: .restart)
        }
    }

    private func metricCard(title: String, value: String, detail: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(BDColor.logicArgumentAccent)
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(BDColor.textPrimary)
            Text(detail)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(BDColor.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(BDColor.panelSecondaryFill))
    }

    private func modifierColor(_ type: ArgumentModifierType) -> Color {
        switch type {
        case .strengthen:  .green
        case .weaken:      .red
        case .irrelevant:  .gray
        }
    }
}
