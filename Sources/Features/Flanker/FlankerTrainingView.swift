import SwiftUI

struct FlankerTrainingView: View {
    private enum FocusTarget: Hashable {
        case start
        case left
        case right
        case cancel
        case close
    }

    @Environment(AppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedTarget: FocusTarget?

    private var coordinator: FlankerCoordinator { appModel.flanker }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            if let engine = coordinator.engine, !engine.isComplete {
                activeView(engine: engine)
            } else if let result = coordinator.lastResult, let m = result.flankerMetrics {
                resultView(metrics: m)
            } else {
                idleView
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            focusedTarget = coordinator.engine == nil ? .start : .left
        }
        .onChange(of: coordinator.engine?.phase) { _, phase in
            switch phase {
            case .stimulus, .waitingForResponse:
                focusedTarget = .left
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
        SurfaceCard(title: "Flanker", subtitle: "在统一训练壳层中完成冲突判断与干扰抑制。", accent: BDColor.flankerAccent) {
            VStack(alignment: .leading, spacing: 16) {
                if appModel.settings.adaptiveDifficultyEnabled {
                    Text("当前推荐档位 L\(appModel.adaptiveState(for: .flanker).recommendedStartLevel) · 每局 2 个 block")
                        .font(.system(.caption))
                        .foregroundStyle(BDColor.textSecondary)
                }

                BDInsightCard(
                    title: "训练说明",
                    bodyText: "只判断中间箭头方向，忽略两侧干扰。重点看冲突代价是否下降，同时保持准确率。",
                    accent: BDColor.flankerAccent
                )

                Button("开始训练") {
                    appModel.startFlankerSession()
                }
                .buttonStyle(BDPrimaryButton(accent: BDColor.flankerAccent))
                .keyboardShortcut(.defaultAction)
                .focused($focusedTarget, equals: .start)
            }
        }
    }

    private func activeView(engine: FlankerEngine) -> some View {
        BDTrainingShell(accent: BDColor.flankerAccent) {
            VStack(spacing: 8) {
                Text("试次 \(engine.currentTrialIndex + 1)/\(engine.totalBlocks * engine.currentSpec.trialsPerBlock)")
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
            let canRespond = engine.phase == .stimulus || engine.phase == .waitingForResponse
            VStack(spacing: 16) {
                HStack(spacing: 40) {
                    Button { appModel.handleFlankerResponse(.left) } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 32, weight: .bold))
                            .frame(width: 80, height: 80)
                            .background(Circle().fill(BDColor.flankerAccent.opacity(canRespond ? 0.15 : 0.05)))
                            .foregroundStyle(BDColor.flankerAccent.opacity(canRespond ? 1 : 0.3))
                    }
                    .buttonStyle(BDSpringPressStyle())
                    .disabled(!canRespond)
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    .focused($focusedTarget, equals: .left)

                    Button { appModel.handleFlankerResponse(.right) } label: {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 32, weight: .bold))
                            .frame(width: 80, height: 80)
                            .background(Circle().fill(BDColor.flankerAccent.opacity(canRespond ? 0.15 : 0.05)))
                            .foregroundStyle(BDColor.flankerAccent.opacity(canRespond ? 1 : 0.3))
                    }
                    .buttonStyle(BDSpringPressStyle())
                    .disabled(!canRespond)
                    .keyboardShortcut(.rightArrow, modifiers: [])
                    .focused($focusedTarget, equals: .right)
                }

                ProgressView(value: engine.completionFraction)
                    .tint(BDColor.flankerAccent)
                    .frame(maxWidth: 300)

                Button("取消") { appModel.cancelFlankerSession() }
                    .buttonStyle(BDSecondaryButton(accent: BDColor.error))
                    .keyboardShortcut(.cancelAction)
                    .focused($focusedTarget, equals: .cancel)
            }
        }
        .onAppear { schedulePhase(engine) }
        .onChange(of: engine.phase) { _, _ in schedulePhase(engine) }
    }

    @ViewBuilder
    private func phaseContent(engine: FlankerEngine) -> some View {
        switch engine.phase {
        case .fixation:
            Text("+")
                .font(.system(size: 80, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .transition(.opacity)
        case .stimulus, .waitingForResponse:
            if let trial = engine.currentTrial {
                let arrows = Array(trial.arrows)
                if arrows.count == 5 {
                    HStack(spacing: 8) {
                        Text(String(arrows[0...1]))
                            .foregroundStyle(.tertiary)
                            .blur(radius: 2.5)
                        
                        Text(String(arrows[2]))
                            .foregroundStyle(BDColor.flankerAccent)
                            .shadow(color: BDColor.flankerAccent.opacity(0.8), radius: 16, y: 0)
                            .scaleEffect(1.2)
                            
                        Text(String(arrows[3...4]))
                            .foregroundStyle(.tertiary)
                            .blur(radius: 2.5)
                    }
                    .font(.system(size: 80, weight: .bold, design: .monospaced))
                    .transition(reduceMotion ? .identity : .scale(scale: 0.8).combined(with: .opacity))
                } else {
                    Text(trial.arrows)
                        .font(.system(size: 80, weight: .bold, design: .monospaced))
                }
            }
        case .feedback(let correct):
            VStack(spacing: 12) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(correct ? BDColor.green : BDColor.error)
                Text(correct ? "抓住了中间目标" : "注意只判断中间箭头")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(correct ? BDColor.green : BDColor.error)
            }
            .transition(reduceMotion ? .identity : .scale.combined(with: .opacity))
            .offset(x: correct ? 0 : 8)
        default:
            Color.clear
        }
    }

    private func schedulePhase(_ engine: FlankerEngine) {
        switch engine.phase {
        case .idle:
            engine.beginTrial()
        case .fixation:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.currentSpec.fixationDurationMs)) {
                guard engine.phase == .fixation else { return }
                engine.showStimulus()
            }
        case .stimulus:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.currentSpec.stimulusDurationMs)) {
                guard engine.phase == .stimulus else { return }
                engine.enterResponseWindow()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.currentSpec.responseWindowMs)) {
                guard engine.phase == .stimulus || engine.phase == .waitingForResponse else { return }
                engine.recordTimeout()
            }
        case .feedback:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(220)) {
                engine.advanceToNext()
                if engine.isComplete {
                    appModel.finalizeFlankerIfComplete()
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

    private func resultView(metrics: FlankerMetrics) -> some View {
        BDResultPanel(title: "Flanker 完成", accent: BDColor.flankerAccent) {
            Text("查看本轮冲突控制表现")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(BDColor.flankerAccent)

            HStack(spacing: 16) {
                FResultCard(label: "冲突代价", value: "\(Int(metrics.conflictCost * 1000))ms", color: BDColor.flankerAccent)
                FResultCard(label: "正确率", value: "\(Int(metrics.accuracy * 100))%", color: BDColor.green)
                FResultCard(label: "试次", value: "\(metrics.totalTrials)", color: BDColor.warm)
            }
            .frame(maxWidth: 400)

            Button("关闭") { appModel.dismissFlankerResult() }
                .buttonStyle(BDSecondaryButton(accent: BDColor.flankerAccent))
                .keyboardShortcut(.defaultAction)
                .focused($focusedTarget, equals: .close)
        }
    }

    // feedbackText removed
}

private struct FResultCard: View {
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
