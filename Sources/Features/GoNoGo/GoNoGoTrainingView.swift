import SwiftUI

struct GoNoGoTrainingView: View {
    private enum FocusTarget: Hashable {
        case start
        case respond
        case cancel
        case close
    }

    @Environment(AppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedTarget: FocusTarget?

    private var coordinator: GoNoGoCoordinator { appModel.goNoGo }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            if let engine = coordinator.engine, !engine.isComplete {
                activeView(engine: engine)
            } else if let result = coordinator.lastResult, let m = result.goNoGoMetrics {
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
            case .stimulus:
                focusedTarget = .respond
            case .fixation, .feedback, .iti, .idle, .blockBreak:
                focusedTarget = .cancel
            case .completed:
                focusedTarget = .close
            case .none:
                focusedTarget = coordinator.lastResult == nil ? .start : .close
            }
        }
    }

    private var idleView: some View {
        SurfaceCard(title: "Go/No-Go", subtitle: "在统一训练壳层中完成启动控制与抑制控制。", accent: BDColor.goNoGoAccent) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    InfoPill(title: "Go 用空格响应", accent: BDColor.goNoGoAccent)
                    InfoPill(title: "No-Go 保持抑制", accent: BDColor.error)
                }

                BDInsightCard(
                    title: "训练说明",
                    bodyText: "绿色圆形立即响应，红色方形保持不动。先稳住 No-Go 正确率，再看 d' 与 Go RT。",
                    accent: BDColor.goNoGoAccent
                )

                if appModel.settings.adaptiveDifficultyEnabled {
                    Text("当前推荐档位 L\(appModel.adaptiveState(for: .goNoGo).recommendedStartLevel) · 每局 2 个 block")
                        .font(.system(.caption))
                        .foregroundStyle(BDColor.textSecondary)
                }

                Button("开始训练") {
                    appModel.startGoNoGoSession()
                }
                .buttonStyle(BDPrimaryButton(accent: BDColor.goNoGoAccent))
                .keyboardShortcut(.defaultAction)
                .focused($focusedTarget, equals: .start)
            }
        }
    }

    private func activeView(engine: GoNoGoEngine) -> some View {
        BDTrainingShell(accent: BDColor.goNoGoAccent) {
            VStack(spacing: 8) {
                Text("试次 \(engine.currentTrialIndex + 1)/\(engine.trials.count)")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)
                Text("L\(engine.currentLevel) · Block \(engine.currentBlock + 1)/\(engine.totalBlocks)")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        } stage: {
            phaseContent(engine: engine)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(height: 280)
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7), value: engine.phase)
        } footer: {
            VStack(spacing: 16) {
                if engine.phase == .stimulus {
                    Button("按空格或点击") {
                        appModel.handleGoNoGoTap()
                    }
                    .buttonStyle(BDPrimaryButton(accent: BDColor.goNoGoAccent))
                    .keyboardShortcut(.space, modifiers: [])
                    .focused($focusedTarget, equals: .respond)
                }

                ProgressView(value: engine.completionFraction)
                    .tint(BDColor.goNoGoAccent)
                    .frame(maxWidth: 300)

                Button("取消") { appModel.cancelGoNoGoSession() }
                    .buttonStyle(BDSecondaryButton(accent: BDColor.error))
                    .keyboardShortcut(.cancelAction)
                    .focused($focusedTarget, equals: .cancel)
            }
        }
        .onAppear { schedulePhase(engine) }
        .onChange(of: engine.phase) { _, _ in schedulePhase(engine) }
    }

    @ViewBuilder
    private func phaseContent(engine: GoNoGoEngine) -> some View {
        switch engine.phase {
        case .fixation:
            Text("+")
                .font(.system(size: 80, weight: .light, design: .rounded))
                .foregroundStyle(.tertiary)
                .transition(.opacity)
        case .stimulus:
            if let trial = engine.currentTrial {
                if trial.stimulusType == .go {
                    ZStack {
                        Circle().fill(BDColor.green)
                        Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 6)
                    }
                    .frame(width: 140, height: 140)
                    .shadow(color: BDColor.green.opacity(0.5), radius: 24, y: 8)
                    .transition(reduceMotion ? .identity : .scale(scale: 0.5).combined(with: .opacity))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 32, style: .continuous).fill(BDColor.error)
                        RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Color.white.opacity(0.4), lineWidth: 6)
                    }
                    .frame(width: 140, height: 140)
                    .shadow(color: BDColor.error.opacity(0.5), radius: 24, y: 8)
                    .transition(reduceMotion ? .identity : .scale(scale: 0.5).combined(with: .opacity))
                }
            }
        case .feedback(let correct):
            VStack(spacing: 8) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(correct ? BDColor.green : BDColor.error)
                Text(correct ? "控制稳定" : "抑制或启动判断出错")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(correct ? BDColor.green : BDColor.error)
            }
            .transition(reduceMotion ? .identity : .scale.combined(with: .opacity))
            .offset(x: correct ? 0 : 8) // simple shake attempt
        default:
            Color.clear
        }
    }

    private func schedulePhase(_ engine: GoNoGoEngine) {
        switch engine.phase {
        case .idle:
            engine.beginTrial()
        case .fixation:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.currentSpec.fixationDurationMs)) {
                guard engine.phase == .fixation else { return }
                engine.showStimulus()
            }
        case .stimulus:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.currentSpec.responseWindowMs)) {
                guard engine.phase == .stimulus else { return }
                engine.recordTimeout()
            }
        case .feedback:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(220)) {
                engine.advanceToNext()
                if engine.isComplete {
                    appModel.finalizeGoNoGoIfComplete()
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

    private func resultView(metrics: GoNoGoMetrics) -> some View {
        BDResultPanel(title: "Go/No-Go 完成", accent: BDColor.goNoGoAccent) {
            Text("查看本轮抑制控制表现")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(BDColor.goNoGoAccent)

            HStack(spacing: 16) {
                ResultCard(label: "d'", value: String(format: "%.2f", metrics.dPrime), color: BDColor.goNoGoAccent)
                ResultCard(label: "No-Go正确", value: "\(Int(metrics.noGoAccuracy * 100))%", color: BDColor.green)
                ResultCard(label: "Go RT", value: "\(Int(metrics.goRT * 1000))ms", color: BDColor.warm)
            }
            .frame(maxWidth: 400)

            Button("关闭") { appModel.dismissGoNoGoResult() }
                .buttonStyle(BDSecondaryButton(accent: BDColor.goNoGoAccent))
                .keyboardShortcut(.defaultAction)
                .focused($focusedTarget, equals: .close)
        }
    }

    // feedbackText removed
}

private struct ResultCard: View {
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
