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
        SurfaceCard(title: "视觉搜索", subtitle: "在干扰物中快速定位目标，同时保持颜色和形状双重匹配。", accent: BDColor.visualSearchAccent) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    InfoPill(title: "核心指标 搜索斜率", accent: BDColor.visualSearchAccent)
                    if appModel.settings.adaptiveDifficultyEnabled {
                        InfoPill(title: "推荐 L\(appModel.adaptiveState(for: .visualSearch).recommendedStartLevel)", accent: BDColor.teal)
                    }
                }

                BDInsightCard(
                    title: "训练目标",
                    bodyText: "在复杂视觉场中稳定判断目标是否存在。先稳住准确率，再降低每个项目的平均搜索耗时。",
                    accent: BDColor.visualSearchAccent
                )

                Button("开始训练") {
                    appModel.startVisualSearchSession()
                }
                .buttonStyle(BDPrimaryButton(accent: BDColor.visualSearchAccent))
            }
        }
    }

    private func activeView(engine: VisualSearchEngine) -> some View {
        BDTrainingShell(accent: BDColor.visualSearchAccent) {
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    Text("试次 \(engine.currentTrialIndex + 1)/\(engine.trials.count)")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(BDColor.textSecondary)
                    Text("L\(engine.currentLevel) · Block \(engine.currentBlock + 1)/\(engine.totalBlocks)")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)

                    let target = engine.currentTrial?.target ?? engine.target
                    HStack(spacing: 4) {
                        Text("目标：")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(BDColor.textSecondary)
                        shapeView(shape: target.shape, color: target.color)
                            .frame(width: 18, height: 18)
                        Text("\(colorName(target.color))\(shapeName(target.shape))")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(BDColor.visualSearchAccent)
                    }
                }
            }
        } stage: {
            ZStack {
                switch engine.phase {
                case .fixation:
                    Text("+")
                        .font(.system(size: 36, weight: .light, design: .rounded))
                        .foregroundStyle(.secondary)
                case .display:
                    if let trial = engine.currentTrial {
                        searchFieldView(trial: trial) { itemID in
                            _ = appModel.handleVisualSearchResponse(present: true, selectedItemID: itemID)
                        }
                    }
                case .feedback(let correct):
                    VStack(spacing: 8) {
                        Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(correct ? BDColor.green : BDColor.error)
                        Text(correct ? "判断正确" : "重新检查目标是否存在")
                            .font(.system(.callout, design: .rounded, weight: .medium))
                            .foregroundStyle(BDColor.textSecondary)
                    }
                default:
                    Color.clear
                }
            }
            #if os(iOS)
            .frame(width: UIScreen.main.bounds.width - 48,
                   height: UIScreen.main.bounds.width - 48)
            #else
            .frame(width: 400, height: 400)
            #endif
        } footer: {
            VStack(spacing: 16) {
            HStack(spacing: 20) {
                Button {
                    _ = appModel.handleVisualSearchResponse(present: false)
                } label: {
                    Text("没有匹配")
                }
                .buttonStyle(BDSecondaryButton(accent: BDColor.teal))
                .keyboardShortcut("1", modifiers: [])
                .disabled(engine.phase != .display)
            }
            .opacity(engine.phase == .display ? 1 : 0)

            ProgressView(value: engine.completionFraction)
                .tint(BDColor.visualSearchAccent)
                .frame(maxWidth: 300)

            Button("取消") { appModel.cancelVisualSearchSession() }
                .buttonStyle(BDSecondaryButton(accent: BDColor.error))
        }
        }
        .onAppear { schedulePhase(engine) }
        .onChange(of: engine.phase) { _, _ in schedulePhase(engine) }
    }

    private func schedulePhase(_ engine: VisualSearchEngine) {
        switch engine.phase {
        case .idle:
            engine.beginTrial()
        case .fixation:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.currentSpec.fixationMs)) {
                guard engine.phase == .fixation else { return }
                engine.showDisplay()
            }
        case .feedback:
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(engine.currentSpec.feedbackMs)) {
                guard case .feedback = engine.phase else { return }
                engine.advanceToNext()
                if engine.isComplete {
                    appModel.finalizeVisualSearchIfComplete()
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

    private func searchFieldView(trial: VisualSearchTrial, onSelect: @escaping (Int) -> Void) -> some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                ForEach(trial.items) { item in
                    searchItemView(
                        item: item,
                        date: timeline.date
                    )
                    .position(x: item.position.x * geo.size.width, y: item.position.y * geo.size.height)
                    .onTapGesture {
                        onSelect(item.id)
                    }
                }
            }
        }
    }

    private func searchItemView(item: SearchItem, date: Date) -> some View {
        let elapsed = date.timeIntervalSinceReferenceDate
        let rotation = item.rotationDegrees + elapsed * item.spinDegreesPerSecond
        return ZStack {
            ZStack {
                shapeView(shape: item.shape, color: item.color)
                if item.spinDegreesPerSecond != 0 {
                    Circle()
                        .fill(Color.white.opacity(0.72))
                        .frame(width: 4, height: 4)
                        .offset(x: 6, y: -6)
                }
            }
                .frame(width: 24, height: 24)
                .rotationEffect(.degrees(rotation))
                .shadow(color: searchColor(item.color).opacity(0.12), radius: 3)
        }
        .frame(width: 40, height: 40)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func shapeView(shape: SearchShape, color: SearchColor) -> some View {
        let fillColor = searchColor(color)
        switch shape {
        case .circle:   Circle().fill(fillColor)
        case .square:   Rectangle().fill(fillColor)
        case .triangle: TriangleShape().fill(fillColor)
        case .diamond:  DiamondShape().fill(fillColor)
        case .pentagon: PolygonShape(sides: 5).fill(fillColor)
        case .hexagon:  PolygonShape(sides: 6).fill(fillColor)
        case .star:     StarShape(points: 5).fill(fillColor)
        case .capsule:  Capsule().fill(fillColor)
        }
    }

    private func searchColor(_ color: SearchColor) -> Color {
        switch color {
        case .red:
            Color(light: .init(red: 0.86, green: 0.05, blue: 0.08), dark: .init(red: 1.00, green: 0.23, blue: 0.25))
        case .blue:
            Color(light: .init(red: 0.05, green: 0.30, blue: 0.88), dark: .init(red: 0.30, green: 0.56, blue: 1.00))
        case .green:
            Color(light: .init(red: 0.02, green: 0.56, blue: 0.25), dark: .init(red: 0.24, green: 0.82, blue: 0.43))
        case .yellow:
            Color(light: .init(red: 0.92, green: 0.72, blue: 0.02), dark: .init(red: 1.00, green: 0.84, blue: 0.18))
        case .purple:
            Color(light: .init(red: 0.45, green: 0.18, blue: 0.82), dark: .init(red: 0.68, green: 0.45, blue: 1.00))
        case .orange:
            Color(light: .init(red: 0.94, green: 0.39, blue: 0.00), dark: .init(red: 1.00, green: 0.55, blue: 0.16))
        case .pink:
            Color(light: .init(red: 0.86, green: 0.06, blue: 0.54), dark: .init(red: 1.00, green: 0.35, blue: 0.70))
        }
    }

    private func colorName(_ color: SearchColor) -> String {
        switch color {
        case .red: "红色"
        case .blue: "蓝色"
        case .green: "绿色"
        case .yellow: "黄色"
        case .purple: "紫色"
        case .orange: "橙色"
        case .pink: "粉色"
        }
    }

    private func shapeName(_ shape: SearchShape) -> String {
        switch shape {
        case .circle: "圆形"
        case .square: "方块"
        case .triangle: "三角"
        case .diamond: "菱形"
        case .pentagon: "五边形"
        case .hexagon: "六边形"
        case .star: "星形"
        case .capsule: "胶囊形"
        }
    }

    private func resultView(metrics: VisualSearchMetrics) -> some View {
        let feedback = resultFeedback(for: metrics)
        return BDResultPanel(title: "视觉搜索完成", accent: BDColor.visualSearchAccent) {
            Text(feedback.title)
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(feedback.color)

            HStack(spacing: 16) {
                VSResultCard(label: "搜索斜率", value: "\(Int(metrics.searchSlope * 1000))ms/项", color: BDColor.visualSearchAccent)
                VSResultCard(label: "正确率", value: "\(Int(metrics.accuracy * 100))%", color: BDColor.green)
                VSResultCard(label: "误报率", value: "\(Int(metrics.errorRate * 100))%", color: BDColor.warm)
            }
            .frame(maxWidth: 400)

            Text(feedback.note)
                .font(.system(.callout))
                .foregroundStyle(BDColor.textSecondary)

            Button("关闭") { appModel.dismissVisualSearchResult() }
                .buttonStyle(BDSecondaryButton(accent: BDColor.visualSearchAccent))
        }
    }

    private func resultFeedback(for metrics: VisualSearchMetrics) -> (title: String, note: String, color: Color) {
        if metrics.accuracy >= 0.85 && metrics.errorRate <= 0.15 {
            return ("达标", "本轮搜索稳定，目标判断基本可靠。", BDColor.green)
        }
        if metrics.accuracy >= 0.7 && metrics.errorRate <= 0.3 {
            return ("一般", "能找到大部分目标，但干扰抑制还不够稳。", BDColor.warm)
        }
        return ("失准", "这轮误判偏多，先稳住准确率再追速度。", BDColor.error)
    }

    private func feedbackText(_ engine: VisualSearchEngine) -> String {
        switch engine.phase {
        case .fixation:
            return "准备进入搜索场"
        case .display:
            return "同时匹配颜色和形状"
        case .feedback(let correct):
            guard let trial = engine.currentTrial else {
                return correct ? "正确" : "错误"
            }
            if correct {
                return trial.targetPresent ? "目标存在，已正确锁定" : "目标不存在，已正确排除"
            }
            return trial.targetPresent ? "目标其实存在于搜索场中" : "本轮实际上没有目标"
        case let .blockBreak(_, outcome, nextLevel):
            switch outcome {
            case .promote:
                return "搜索效率提高，升到 L\(nextLevel)"
            case .demote:
                return "本 block 调整到 L\(nextLevel)"
            case .stay:
                return "本 block 保持 L\(nextLevel)"
            }
        default:
            return coordinator.statusMessage
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

private struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct PolygonShape: Shape {
    let sides: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let count = max(sides, 3)

        for index in 0..<count {
            let angle = (Double(index) / Double(count) * 2 * Double.pi) - Double.pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

private struct StarShape: Shape {
    let points: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.46
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let count = max(points, 3) * 2

        for index in 0..<count {
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = (Double(index) / Double(count) * 2 * Double.pi) - Double.pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
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
