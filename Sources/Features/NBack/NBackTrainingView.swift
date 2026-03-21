import SwiftUI

struct NBackTrainingView: View {
    @Environment(AppModel.self) private var appModel

    private var coordinator: NBackCoordinator { appModel.nBack }

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
            Text("起始 N = \(appModel.settings.nBackStartingN)  ·  核心指标：d'")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

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
            Text("\(engine.currentN)-Back  ·  Block \(engine.currentBlock + 1)/\(engine.config.blockCount)")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

            phaseContent(engine: engine)
                .frame(height: 150)

            Button {
                appModel.handleNBackMatch()
            } label: {
                Text("匹配")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 48).padding(.vertical, 14)
                    .background(Capsule().fill(engine.phase == .stimulus ? BDColor.nBackAccent : BDColor.nBackAccent.opacity(0.3)))
            }
            .buttonStyle(.plain)
            .disabled(engine.phase != .stimulus)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.config.stimulusDurationMs)) {
                guard engine.phase == .stimulus else { return }
                engine.enterISI()
            }
        case .isi:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.config.isiMs)) {
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
        VStack(spacing: 20) {
            Text("N-Back 完成")
                .font(.system(.title2, design: .rounded, weight: .bold))
            HStack(spacing: 16) {
                NResultCard(label: "N Level", value: "\(metrics.nLevel)", color: BDColor.nBackAccent)
                NResultCard(label: "d'", value: String(format: "%.2f", metrics.dPrime), color: BDColor.green)
                NResultCard(label: "命中率", value: "\(Int(metrics.hitRate * 100))%", color: BDColor.warm)
            }
            .frame(maxWidth: 400)

            Button("关闭") { appModel.dismissNBackResult() }
                .buttonStyle(.bordered)
        }
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
