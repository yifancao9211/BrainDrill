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
    @State private var showCancelConfirmation = false
    @State private var countdown = CountdownState()
    @State private var phaseTimer = PhaseScheduler()

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
        .overlay { BDCountdownOverlay(countdown: countdown) }
        .onAppear {
            focusedTarget = coordinator.engine == nil ? .start : .respond
        }
        .onChange(of: coordinator.engine?.phase) { _, phase in
            switch phase {
            case .stimulus, .isi:
                focusedTarget = .respond
            case .idle, .blockBreak, .practiceComplete:
                focusedTarget = .cancel
            case .completed:
                focusedTarget = .close
            case .none:
                focusedTarget = coordinator.lastResult == nil ? .start : .close
            }
        }
    }

    private var idleView: some View {
        BDTrainingIdleCard(
            title: "N-Back",
            subtitle: "进入训练前先确认推荐负荷和目标指标。",
            accent: BDColor.nBackAccent,
            insightTitle: "训练说明",
            insightBody: "数字会自动逐个播放。只有当前数字与 N 步前相同时才按一次「匹配」，不是目标就不要按。前 N 个数字只看不答。正式计分前会有一小段不计分的练习帮你进入状态。"
        ) {
            countdown.onComplete = { appModel.startNBackSession() }
            countdown.start()
        } pills: {
            InfoPill(title: "推荐 \(recommendedStartN)-Back", accent: BDColor.nBackAccent)
            InfoPill(title: "核心指标 d'", accent: BDColor.green)
        } extra: {
            HStack(spacing: 14) {
                BDStatCard(label: "播放方式", value: "自动", accent: BDColor.nBackAccent)
                BDStatCard(label: "响应", value: "命中时按匹配", accent: BDColor.teal)
            }
        }
    }

    private func activeView(engine: NBackEngine) -> some View {
        BDTrainingShell(accent: BDColor.nBackAccent) {
            VStack(spacing: 8) {
                Text(engine.isPractice
                     ? "\(engine.currentN)-Back  ·  练习"
                     : "\(engine.currentN)-Back  ·  Block \(engine.currentBlock + 1)/\(engine.config.blockCount)")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(engine.isPractice ? BDColor.warm : BDColor.textSecondary)

                Text("自动播放 · 与 \(engine.currentN) 步前相同时按「匹配」")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        } stage: {
            phaseContent(engine: engine)
                .frame(height: 180)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.12), value: engine.phase)
        } footer: {
            VStack(spacing: 16) {
                responseControls(engine: engine)

                ProgressView(value: engine.completionFraction)
                    .tint(BDColor.nBackAccent)
                    .frame(maxWidth: 300)

                Button("取消") { showCancelConfirmation = true }
                    .buttonStyle(BDSecondaryButton(accent: BDColor.error))
                    .keyboardShortcut(.cancelAction)
                    .focused($focusedTarget, equals: .cancel)
                    .confirmationDialog("确定取消训练？", isPresented: $showCancelConfirmation, titleVisibility: .visible) {
                        Button("取消训练", role: .destructive) { appModel.cancelNBackSession() }
                        Button("继续训练", role: .cancel) {}
                    } message: {
                        Text("本次训练不会计入记录。")
                    }
            }
        }
        .onAppear { schedulePhase(engine) }
        .onChange(of: engine.phase) { _, _ in schedulePhase(engine) }
        .onDisappear { phaseTimer.cancel() }
    }

    @ViewBuilder
    private func responseControls(engine: NBackEngine) -> some View {
        switch engine.phase {
        case .blockBreak:
            Text("准备下一组…")
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(BDColor.textSecondary)
                .frame(height: 44)
        case .practiceComplete:
            Text("准备开始正式测试…")
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(BDColor.textSecondary)
                .frame(height: 44)
        case .stimulus, .isi:
            if engine.isObservationOnly {
                Text("记忆铺垫 · 第 \(engine.currentTrialIndex + 1)/\(engine.currentN) 个")
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(height: 44)
            } else {
                Button {
                    appModel.handleNBackMatch()
                } label: {
                    Label(engine.respondedThisTrial ? "已标记匹配" : "匹配", systemImage: engine.respondedThisTrial ? "checkmark" : "arrow.uturn.backward")
                        .frame(minWidth: 160)
                }
                .buttonStyle(BDPrimaryButton(accent: BDColor.nBackAccent))
                .disabled(engine.respondedThisTrial)
                .keyboardShortcut(.space, modifiers: [])
                .focused($focusedTarget, equals: .respond)
            }
        default:
            Color.clear.frame(height: 44)
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
        case .isi:
            // Blank inter-stimulus interval; keep a faint fixation so the eye stays centered.
            Text("·")
                .font(.system(size: 60, weight: .light, design: .rounded))
                .foregroundStyle(.tertiary)
                .frame(width: 140, height: 140)
        case let .blockBreak(blockIndex, nextN):
            VStack(spacing: 8) {
                Text("第 \(blockIndex) 组完成")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(BDColor.nBackAccent)
                Text("下一组：\(nextN)-Back")
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)
            }
        case .practiceComplete:
            VStack(spacing: 8) {
                Text("练习结束")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(BDColor.warm)
                Text("接下来开始正式计分")
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)
            }
        case .idle, .completed:
            Color.clear
        }
    }

    /// Drives the auto-paced stimulus stream off phase transitions.
    private func schedulePhase(_ engine: NBackEngine) {
        switch engine.phase {
        case .idle:
            engine.beginTrial()
        case .stimulus:
            phaseTimer.schedule(afterMilliseconds: engine.currentStimulusDurationMs) {
                guard engine.phase == .stimulus else { return }
                engine.enterISI()
            }
        case .isi:
            phaseTimer.schedule(afterMilliseconds: engine.currentISIMs) {
                guard engine.phase == .isi else { return }
                engine.advanceTrial()
                if engine.isComplete {
                    appModel.finalizeNBackIfComplete()
                }
            }
        case let .blockBreak(_, nextN):
            phaseTimer.schedule(afterMilliseconds: 2000) {
                guard case .blockBreak = engine.phase else { return }
                engine.startNextBlock(n: nextN)
            }
        case .practiceComplete:
            phaseTimer.schedule(afterMilliseconds: 2000) {
                guard engine.phase == .practiceComplete else { return }
                engine.beginTrial() // start the first scored block
            }
        case .completed:
            break
        }
    }

    private func resultView(metrics: NBackMetrics) -> some View {
        let feedback = resultFeedback(for: metrics)
        return BDResultPanel(title: "N-Back 完成", accent: BDColor.nBackAccent) {
            Text(feedback.title)
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(feedback.color)

            HStack(spacing: 16) {
                BDResultMetricCard(label: "N Level", value: "\(metrics.nLevel)", color: BDColor.nBackAccent)
                BDResultMetricCard(label: "d'", value: String(format: "%.2f", metrics.dPrime), color: BDColor.green)
                BDResultMetricCard(label: "命中率", value: "\(Int(metrics.hitRate * 100))%", color: BDColor.warm)
                BDResultMetricCard(label: "虚报率", value: "\(Int(metrics.falseAlarmRate * 100))%", color: BDColor.error)
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
