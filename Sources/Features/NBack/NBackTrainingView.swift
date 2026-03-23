import SwiftUI

struct NBackTrainingView: View {
    @Environment(AppModel.self) private var appModel

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
    }

    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "number.square.fill")
                .font(.system(size: 48))
                .foregroundStyle(BDColor.nBackAccent.opacity(0.6))
            Text("N-Back 记忆训练")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text("判断当前数字是否与 N 步前的数字相同")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("当前推荐起始 N = \(recommendedStartN)  ·  核心指标：d'")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
            Text("显示 \(appModel.settings.nBackStimulusDurationMs)ms  ·  间隔 \(appModel.settings.nBackISIMs)ms")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
            Text("每局 2 个 block，达到准确阈值后下一 block 自动升降 N。")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(BDColor.textSecondary)

            Button {
                appModel.startNBackSession()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("开始训练")
                }
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 40).padding(.vertical, 16)
                .background(Capsule().fill(BDColor.nBackAccent))
            }
            .buttonStyle(.plain)
        }
    }

    private func activeView(engine: NBackEngine) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("\(engine.currentN)-Back  ·  Block \(engine.currentBlock + 1)/\(engine.config.blockCount)")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)

                Text("显示 \(engine.currentStimulusDurationMs)ms  ·  间隔 \(engine.currentISIMs)ms")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)

                BDFeedbackNote(text: coordinator.statusMessage, color: BDColor.nBackAccent)
            }

            BDTrainingStage(accent: BDColor.nBackAccent) {
                phaseContent(engine: engine)
                    .frame(height: 180)
            }

            Button {
                appModel.handleNBackMatch()
            } label: {
                Text(engine.respondedThisTrial ? "已记录" : "匹配")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 48).padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(
                                engine.phase == .stimulus && !engine.respondedThisTrial
                                    ? BDColor.nBackAccent
                                    : BDColor.nBackAccent.opacity(0.3)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(engine.phase != .stimulus || engine.respondedThisTrial)
            .keyboardShortcut(.space, modifiers: [])

            ProgressView(value: engine.completionFraction)
                .tint(BDColor.nBackAccent)
                .frame(maxWidth: 300)

            Button("取消") { appModel.cancelNBackSession() }
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(BDColor.error)
                .buttonStyle(.plain)
        }
        .onAppear { schedulePhase(engine) }
        .onChange(of: engine.phase) { _, _ in schedulePhase(engine) }
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
            .transition(.opacity)
        case .isi:
            Text("+")
                .font(.system(size: 36, weight: .light, design: .rounded))
                .foregroundStyle(.secondary)
        default:
            Color.clear.frame(height: 1)
        }
    }

    private func schedulePhase(_ engine: NBackEngine) {
        switch engine.phase {
        case .idle:
            engine.showStimulus()
        case .stimulus:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.currentStimulusDurationMs)) {
                guard engine.phase == .stimulus else { return }
                engine.enterISI()
            }
        case .feedback:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.feedbackDurationMs)) {
                guard case .feedback = engine.phase else { return }
                engine.dismissFeedback()
            }
        case .isi:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.currentISIMs)) {
                guard engine.phase == .isi else { return }
                engine.advanceToNext()
                if !engine.isComplete {
                    engine.showStimulus()
                } else {
                    if let result = coordinator.buildResultIfComplete() {
                        appModel.recordNBackResult(result)
                    }
                }
            }
        case let .blockBreak(_, nextN):
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
                engine.startNextBlock(n: nextN)
                engine.showStimulus()
            }
        default:
            break
        }
    }

    private func resultView(metrics: NBackMetrics) -> some View {
        let feedback = resultFeedback(for: metrics)
        return BDResultPanel(title: "N-Back 完成", accent: BDColor.nBackAccent) {
            HStack(spacing: 16) {
                NResultCard(label: "结果", value: feedback.title, color: feedback.color)
                NResultCard(label: "N Level", value: "\(metrics.nLevel)", color: BDColor.nBackAccent)
                NResultCard(label: "d'", value: String(format: "%.2f", metrics.dPrime), color: BDColor.green)
                NResultCard(label: "命中率", value: "\(Int(metrics.hitRate * 100))%", color: BDColor.warm)
            }
            .frame(maxWidth: 400)

            BDFeedbackNote(text: feedback.note, color: feedback.color)

            if appModel.settings.adaptiveDifficultyEnabled {
                Text("下次训练将从 \(recommendedStartN)-Back 开始。")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(BDColor.textSecondary)
            }

            Button("关闭") { appModel.dismissNBackResult() }
                .buttonStyle(.bordered)
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
