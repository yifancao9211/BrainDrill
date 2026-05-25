import SwiftUI

struct NBackTrainingView: View {
    private enum FocusTarget: Hashable {
        case start
        case respond
        case cancel
        case close
    }

    @Environment(AppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedTarget: FocusTarget?

    private var coordinator: NBackCoordinator { appModel.nBack }

    private var recommendedStartN: Int {
        if appModel.settings.adaptiveDifficultyEnabled {
            return min(max(appModel.adaptiveState(for: .nBack).recommendedStartLevel, 1), 5)
        }
        return appModel.settings.nBackStartingN
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            if let engine = coordinator.engine, !engine.isComplete {
                activeView(engine: engine)
            } else if let result = coordinator.lastResult, let m = result.nBackMetrics {
                resultView(metrics: m)
            } else {
                idleView
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            focusedTarget = coordinator.engine == nil ? .start : .respond
        }
        .onChange(of: coordinator.engine?.phase) { _, phase in
            switch phase {
            case .stimulus, .feedback, .idle, .blockBreak:
                focusedTarget = .respond
            case .completed:
                focusedTarget = .close
            case .none:
                focusedTarget = coordinator.lastResult == nil ? .start : .close
            }
        }
    }

    private var idleView: some View {
        SurfaceCard(title: "N-Back", subtitle: "进入训练前先确认推荐负荷和目标指标。", accent: BDColor.nBackAccent) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    InfoPill(title: "推荐 \(recommendedStartN)-Back", accent: BDColor.nBackAccent)
                    InfoPill(title: "核心指标 d'", accent: BDColor.green)
                }

                BDInsightCard(
                    title: "训练说明",
                    bodyText: "判断当前数字是否与 N 步前相同。先稳定命中和抑制误报，再逐步提高负荷。",
                    accent: BDColor.nBackAccent
                )

                HStack(spacing: 14) {
                    BDStatCard(label: "推进方式", value: "自主", accent: BDColor.nBackAccent)
                    BDStatCard(label: "节奏记录", value: "每题间隔", accent: BDColor.teal)
                }

                Button("开始训练") {
                    appModel.startNBackSession()
                }
                .buttonStyle(BDPrimaryButton(accent: BDColor.nBackAccent))
                .keyboardShortcut(.defaultAction)
                .focused($focusedTarget, equals: .start)
            }
        }
    }

    private func activeView(engine: NBackEngine) -> some View {
        BDTrainingShell(accent: BDColor.nBackAccent) {
            VStack(spacing: 8) {
                Text("\(engine.currentN)-Back  ·  Block \(engine.currentBlock + 1)/\(engine.config.blockCount)")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)

                Text("自主推进 · 记录每题决策间隔")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        } stage: {
            phaseContent(engine: engine)
                .frame(height: 180)
        } footer: {
            VStack(spacing: 16) {
                if case .blockBreak = engine.phase {
                    Button {
                        appModel.handleNBackNext()
                    } label: {
                        Text("开始下一组")
                    }
                    .buttonStyle(BDSecondaryButton(accent: BDColor.nBackAccent))
                    .keyboardShortcut(.return, modifiers: [])
                } else if engine.phase == .idle {
                    Button {
                        appModel.handleNBackNext()
                    } label: {
                        Text("开始本题")
                    }
                    .buttonStyle(BDSecondaryButton(accent: BDColor.nBackAccent))
                    .keyboardShortcut(.return, modifiers: [])
                } else {
                    HStack(spacing: 12) {
                        Button {
                            appModel.handleNBackMatch()
                        } label: {
                            Text("匹配")
                        }
                        .buttonStyle(BDPrimaryButton(accent: BDColor.nBackAccent))
                        .disabled(engine.phase != .stimulus || engine.respondedThisTrial)
                        .keyboardShortcut("1", modifiers: [])
                        .focused($focusedTarget, equals: .respond)

                        Button {
                            appModel.handleNBackNonMatch()
                        } label: {
                            Text("不匹配")
                        }
                        .buttonStyle(BDSecondaryButton(accent: BDColor.nBackAccent))
                        .disabled(engine.phase != .stimulus || engine.respondedThisTrial)
                        .keyboardShortcut("2", modifiers: [])
                    }
                }

            ProgressView(value: engine.completionFraction)
                .tint(BDColor.nBackAccent)
                .frame(maxWidth: 300)

            Button("取消") { appModel.cancelNBackSession() }
                .buttonStyle(BDSecondaryButton(accent: BDColor.error))
                .keyboardShortcut(.cancelAction)
                .focused($focusedTarget, equals: .cancel)
        }
        }
    }

    @ViewBuilder
    private func phaseContent(engine: NBackEngine) -> some View {
        switch engine.phase {
        case .stimulus:
            if let stimulus = engine.currentStimulus {
                Text("\(stimulus)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundStyle(BDColor.nBackAccent)
                    .frame(width: 140, height: 140)
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(BDColor.nBackAccent.opacity(0.1)))
            }
        case .feedback(let correct):
            VStack(spacing: 8) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(correct ? BDColor.green : BDColor.error)
                Text(correct ? "命中" : (engine.respondedThisTrial ? "虚报" : "漏判"))
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .foregroundStyle(correct ? BDColor.green : BDColor.error)
            }
            .transition(reduceMotion ? .identity : .opacity)
        case let .blockBreak(blockIndex, nextN):
            VStack(spacing: 8) {
                Text("第 \(blockIndex) 组完成")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(BDColor.nBackAccent)
                Text("下一组：\(nextN)-Back")
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)
            }
        case .idle:
            Text("准备好后开始本题")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(BDColor.textSecondary)
        case .completed:
            Color.clear
        }
    }

    private func resultView(metrics: NBackMetrics) -> some View {
        let feedback = resultFeedback(for: metrics)
        return BDResultPanel(title: "N-Back 完成", accent: BDColor.nBackAccent) {
            Text(feedback.title)
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(feedback.color)

            HStack(spacing: 16) {
                NResultCard(label: "N Level", value: "\(metrics.nLevel)", color: BDColor.nBackAccent)
                NResultCard(label: "d'", value: String(format: "%.2f", metrics.dPrime), color: BDColor.green)
                NResultCard(label: "命中率", value: "\(Int(metrics.hitRate * 100))%", color: BDColor.warm)
                NResultCard(label: "均间隔", value: String(format: "%.1fs", metrics.averageDecisionInterval), color: BDColor.teal)
            }
            .frame(maxWidth: 520)

            Text(feedback.note)
                .font(.system(.callout))
                .foregroundStyle(BDColor.textSecondary)

            if appModel.settings.adaptiveDifficultyEnabled {
                Text("下次训练将从 \(recommendedStartN)-Back 开始。")
                    .font(.system(.callout))
                    .foregroundStyle(BDColor.textSecondary)
            }

            Button("关闭") { appModel.dismissNBackResult() }
                .buttonStyle(BDSecondaryButton(accent: BDColor.nBackAccent))
                .keyboardShortcut(.defaultAction)
                .focused($focusedTarget, equals: .close)
        }
    }

    private func resultFeedback(for metrics: NBackMetrics) -> (title: String, note: String, color: Color) {
        if metrics.dPrime >= 1.2 && metrics.hitRate >= 0.7 && metrics.falseAlarmRate <= 0.2 {
            return ("达标", "这轮更新和抑制都比较稳，可以继续加压。", BDColor.green)
        }
        if metrics.dPrime >= 0.6 && metrics.hitRate >= 0.55 {
            return ("一般", "已经抓到部分匹配，但虚报或漏报还偏多。", BDColor.warm)
        }
        return ("失准", "这轮工作记忆负荷偏高，先把准确匹配做稳。", BDColor.error)
    }
}

private struct NResultCard: View {
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
