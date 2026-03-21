import SwiftUI

struct ChangeDetectionTrainingView: View {
    @Environment(AppModel.self) private var appModel

    private var coordinator: ChangeDetectionCoordinator { appModel.changeDetection }

    private let colorPalette: [Color] = [
        .red, .blue, .green, .yellow, .purple, .orange, .pink, .cyan, .mint
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            if let engine = coordinator.engine, !engine.isComplete {
                activeView(engine: engine)
            } else if let result = coordinator.lastResult, let m = result.changeDetectionMetrics {
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
            Image(systemName: "eye.fill")
                .font(.system(size: 48))
                .foregroundStyle(BDColor.changeDetectionAccent.opacity(0.6))
            Text("变更检测训练")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text("记住方块颜色，判断是否发生变化")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
            Text("核心指标：d' 与集合大小")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

            Button {
                appModel.startChangeDetectionSession()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("开始训练")
                }
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 40).padding(.vertical, 16)
                .background(Capsule().fill(BDColor.changeDetectionAccent))
            }
            .buttonStyle(.plain)
        }
    }

    private func activeView(engine: ChangeDetectionEngine) -> some View {
        VStack(spacing: 24) {
            Text("集合大小 \(engine.currentSetSize)  •  试次 \(engine.currentTrialIndex + 1)")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
                    .frame(width: 300, height: 300)

                switch engine.phase {
                case .encoding:
                    if let trial = engine.currentTrial {
                        colorGridView(colors: trial.originalColors, positions: trial.positions)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.config.encodingMs)) {
                                    guard engine.phase == .encoding else { return }
                                    engine.startRetention()
                                }
                            }
                    }
                case .retention:
                    Text("+")
                        .font(.system(size: 36, weight: .light, design: .rounded))
                        .foregroundStyle(.secondary)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.config.retentionMs)) {
                                guard engine.phase == .retention else { return }
                                engine.showProbe()
                            }
                        }
                case .probe:
                    if let trial = engine.currentTrial {
                        colorGridView(colors: trial.probeColors, positions: trial.positions)
                    }
                case .feedback(let correct):
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(correct ? BDColor.green : BDColor.error)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                                engine.advanceToNext()
                                if !engine.isComplete {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
                                        engine.beginTrial()
                                    }
                                } else {
                                    appModel.finalizeChangeDetectionIfComplete()
                                }
                            }
                        }
                case .iti:
                    Color.clear
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
                                engine.beginTrial()
                            }
                        }
                default:
                    EmptyView()
                        .onAppear {
                            engine.beginTrial()
                        }
                }
            }
            .frame(width: 300, height: 300)
            .animation(.easeInOut(duration: 0.15), value: engine.phase)

            if engine.phase == .probe {
                HStack(spacing: 20) {
                    Button {
                        _ = appModel.handleChangeDetectionResponse(changed: false)
                    } label: {
                        Text("没变")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28).padding(.vertical, 14)
                            .background(Capsule().fill(BDColor.teal))
                    }
                    .buttonStyle(.plain)

                    Button {
                        _ = appModel.handleChangeDetectionResponse(changed: true)
                    } label: {
                        Text("变了")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28).padding(.vertical, 14)
                            .background(Capsule().fill(BDColor.choiceRTAccent))
                    }
                    .buttonStyle(.plain)
                }
            }

            ProgressView(value: engine.completionFraction)
                .tint(BDColor.changeDetectionAccent)
                .frame(maxWidth: 300)

            Button("取消") { appModel.cancelChangeDetectionSession() }
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(BDColor.error)
                .buttonStyle(.plain)
        }
    }

    private func colorGridView(colors: [Int], positions: [CGPoint]) -> some View {
        GeometryReader { geo in
            ForEach(Array(colors.enumerated()), id: \.offset) { idx, colorIdx in
                let pos = idx < positions.count ? positions[idx] : CGPoint(x: 0.5, y: 0.5)
                let safeColorIdx = min(colorIdx, colorPalette.count - 1)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(colorPalette[safeColorIdx])
                    .frame(width: 44, height: 44)
                    .position(
                        x: pos.x * geo.size.width,
                        y: pos.y * geo.size.height
                    )
            }
        }
    }

    private func resultView(metrics: ChangeDetectionMetrics) -> some View {
        VStack(spacing: 20) {
            Text("变更检测完成")
                .font(.system(.title2, design: .rounded, weight: .bold))
            HStack(spacing: 16) {
                CDResultCard(label: "d'", value: String(format: "%.2f", metrics.dPrime), color: BDColor.changeDetectionAccent)
                CDResultCard(label: "正确率", value: "\(Int(metrics.accuracy * 100))%", color: BDColor.green)
                CDResultCard(label: "最大集合", value: "\(metrics.maxSetSize)", color: BDColor.warm)
            }
            .frame(maxWidth: 400)

            Button("关闭") { appModel.dismissChangeDetectionResult() }
                .buttonStyle(.bordered)
        }
    }
}

private struct CDResultCard: View {
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
