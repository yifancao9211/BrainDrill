import SwiftUI

struct VisualSearchTrainingView: View {
    @Environment(AppModel.self) private var appModel

    private var coordinator: VisualSearchCoordinator { appModel.visualSearch }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            if let engine = coordinator.engine, !engine.isComplete {
                activeView(engine: engine)
            } else if let result = coordinator.lastResult, let m = result.visualSearchMetrics {
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
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(BDColor.visualSearchAccent.opacity(0.6))
            Text("视觉搜索训练")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text("在干扰物中快速找到目标（需同时匹配颜色和形状）")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("核心指标：搜索斜率 (ms/项)")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

            Button {
                appModel.startVisualSearchSession()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("开始训练")
                }
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 40).padding(.vertical, 16)
                .background(Capsule().fill(BDColor.visualSearchAccent))
            }
            .buttonStyle(.plain)
        }
    }

    private func activeView(engine: VisualSearchEngine) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("试次 \(engine.currentTrialIndex + 1)/\(engine.trials.count)")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Text("找")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                    shapeView(shape: engine.target.shape, color: engine.target.color)
                        .frame(width: 18, height: 18)
                    Text("\(colorName(engine.target.color))\(shapeName(engine.target.shape))")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(BDColor.visualSearchAccent)
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.primary.opacity(0.03))

                switch engine.phase {
                case .fixation:
                    Text("+")
                        .font(.system(size: 36, weight: .light, design: .rounded))
                        .foregroundStyle(.secondary)
                case .display:
                    if let trial = engine.currentTrial {
                        searchFieldView(trial: trial)
                    }
                case .feedback(let correct):
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(correct ? BDColor.green : BDColor.error)
                default:
                    Color.clear.frame(height: 1)
                }
            }
            .frame(width: 400, height: 400)

            if engine.phase == .display {
                HStack(spacing: 20) {
                    Button {
                        _ = appModel.handleVisualSearchResponse(present: false)
                    } label: {
                        Text("没有")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28).padding(.vertical, 14)
                            .background(Capsule().fill(BDColor.teal))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("1", modifiers: [])

                    Button {
                        _ = appModel.handleVisualSearchResponse(present: true)
                    } label: {
                        Text("找到了")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28).padding(.vertical, 14)
                            .background(Capsule().fill(BDColor.visualSearchAccent))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("2", modifiers: [])
                }
            }

            ProgressView(value: engine.completionFraction)
                .tint(BDColor.visualSearchAccent)
                .frame(maxWidth: 300)

            Button("取消") { appModel.cancelVisualSearchSession() }
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(BDColor.error)
                .buttonStyle(.plain)
        }
        .onAppear { schedulePhase(engine) }
        .onChange(of: engine.phase) { _, _ in schedulePhase(engine) }
    }

    private func schedulePhase(_ engine: VisualSearchEngine) {
        switch engine.phase {
        case .idle:
            engine.beginTrial()
        case .fixation:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.config.fixationMs)) {
                guard engine.phase == .fixation else { return }
                engine.showDisplay()
            }
        case .feedback:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.config.feedbackMs)) {
                engine.advanceToNext()
                if engine.isComplete {
                    appModel.finalizeVisualSearchIfComplete()
                }
            }
        case .iti:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.randomITI())) {
                engine.beginTrial()
            }
        default:
            break
        }
    }

    private func searchFieldView(trial: VisualSearchTrial) -> some View {
        GeometryReader { geo in
            ForEach(trial.items) { item in
                shapeView(shape: item.shape, color: item.color)
                    .frame(width: 24, height: 24)
                    .position(x: item.position.x * geo.size.width, y: item.position.y * geo.size.height)
            }
        }
    }

    @ViewBuilder
    private func shapeView(shape: SearchShape, color: SearchColor) -> some View {
        let fillColor = searchColor(color)
        switch shape {
        case .circle:   Circle().fill(fillColor)
        case .square:   Rectangle().fill(fillColor)
        case .triangle: TriangleShape().fill(fillColor)
        }
    }

    private func searchColor(_ color: SearchColor) -> Color {
        switch color {
        case .red: .red; case .blue: .blue; case .green: .green
        }
    }

    private func colorName(_ color: SearchColor) -> String {
        switch color {
        case .red: "红色"; case .blue: "蓝色"; case .green: "绿色"
        }
    }

    private func shapeName(_ shape: SearchShape) -> String {
        switch shape {
        case .circle: "圆形"; case .square: "方块"; case .triangle: "三角"
        }
    }

    private func resultView(metrics: VisualSearchMetrics) -> some View {
        VStack(spacing: 20) {
            Text("视觉搜索完成")
                .font(.system(.title2, design: .rounded, weight: .bold))
            HStack(spacing: 16) {
                VSResultCard(label: "搜索斜率", value: "\(Int(metrics.searchSlope * 1000))ms/项", color: BDColor.visualSearchAccent)
                VSResultCard(label: "正确率", value: "\(Int(metrics.accuracy * 100))%", color: BDColor.green)
                VSResultCard(label: "有目标RT", value: "\(Int(metrics.presentRT * 1000))ms", color: BDColor.warm)
            }
            .frame(maxWidth: 400)

            Button("关闭") { appModel.dismissVisualSearchResult() }
                .buttonStyle(.bordered)
        }
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct VSResultCard: View {
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
