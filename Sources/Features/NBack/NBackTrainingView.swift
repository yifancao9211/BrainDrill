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

            if let stimulus = engine.currentStimulus {
                Text("\(stimulus)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundStyle(BDColor.nBackAccent)
                    .frame(width: 140, height: 140)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(BDColor.nBackAccent.opacity(0.1))
                    )
                    .transition(.scale.combined(with: .opacity))
            }

            Button {
                appModel.handleNBackMatch()
            } label: {
                Text("匹配")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 48).padding(.vertical, 14)
                    .background(Capsule().fill(BDColor.nBackAccent))
            }
            .buttonStyle(.plain)

            ProgressView(value: engine.completionFraction)
                .tint(BDColor.nBackAccent)
                .frame(maxWidth: 300)

            Button("取消") { appModel.cancelNBackSession() }
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(BDColor.error)
                .buttonStyle(.plain)
        }
    }

    private func resultView(metrics: NBackMetrics) -> some View {
        VStack(spacing: 20) {
            Text("N-Back 完成")
                .font(.system(.title2, design: .rounded, weight: .bold))
            HStack(spacing: 16) {
                ResultCard(label: "N Level", value: "\(metrics.nLevel)", color: BDColor.nBackAccent)
                ResultCard(label: "d'", value: String(format: "%.2f", metrics.dPrime), color: BDColor.green)
                ResultCard(label: "命中率", value: "\(Int(metrics.hitRate * 100))%", color: BDColor.warm)
            }
            .frame(maxWidth: 400)

            Button("关闭") { appModel.dismissNBackResult() }
                .buttonStyle(.bordered)
        }
    }
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
