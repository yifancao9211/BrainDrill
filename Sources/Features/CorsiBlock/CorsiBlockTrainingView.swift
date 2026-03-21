import SwiftUI

struct CorsiBlockTrainingView: View {
    @Environment(AppModel.self) private var appModel

    private var coordinator: CorsiBlockCoordinator { appModel.corsiBlock }

    @State private var userInput: [Int] = []
    @State private var selectedMode: CorsiBlockMode = .forward

    private let gridSize = 9
    private let columns = 3

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            if let engine = coordinator.engine, !engine.isComplete {
                activeView(engine: engine)
            } else if let result = coordinator.lastResult, let m = result.corsiBlockMetrics {
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
            Image(systemName: "square.grid.3x3.topleft.filled")
                .font(.system(size: 48))
                .foregroundStyle(BDColor.corsiBlockAccent.opacity(0.6))
            Text("空间广度训练")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text("记住方块亮起的顺序，然后按相同顺序点击")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
            Text("核心指标：最大空间广度 (Span)")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

            Picker("模式", selection: $selectedMode) {
                ForEach(CorsiBlockMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)

            Button {
                userInput = []
                appModel.startCorsiBlockSession(mode: selectedMode)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("开始训练")
                }
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 40).padding(.vertical, 16)
                .background(Capsule().fill(BDColor.corsiBlockAccent))
            }
            .buttonStyle(.plain)
        }
    }

    private func activeView(engine: CorsiBlockEngine) -> some View {
        VStack(spacing: 24) {
            Text("广度 \(engine.currentLength)  •  第 \(engine.trialIndex + 1) 轮")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)

            blockGrid(engine: engine)

            switch engine.phase {
            case .presenting:
                Text("观察方块亮起的顺序")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                    .onAppear { scheduleBlockPresentation(engine: engine) }
            case .recalling:
                recallingControls(engine: engine)
            case .feedback(let correct):
                feedbackView(correct: correct, engine: engine)
            default:
                EmptyView()
            }

            ProgressView(value: engine.completionFraction)
                .tint(BDColor.corsiBlockAccent)
                .frame(maxWidth: 300)

            Button("取消") { appModel.cancelCorsiBlockSession() }
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(BDColor.error)
                .buttonStyle(.plain)
        }
    }

    private func blockGrid(engine: CorsiBlockEngine) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
            ForEach(0..<gridSize, id: \.self) { idx in
                let isHighlighted = engine.phase == .presenting
                    && engine.currentTrial?.sequence[safe: engine.presentingBlockIndex] == idx
                let isSelected = userInput.contains(idx)

                Button {
                    if engine.phase == .recalling && !userInput.contains(idx) {
                        userInput.append(idx)
                    }
                } label: {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isHighlighted ? BDColor.corsiBlockAccent : (isSelected ? BDColor.corsiBlockAccent.opacity(0.4) : BDColor.tileDefault))
                        .frame(height: 64)
                        .overlay(
                            isSelected
                                ? Text("\(userInput.firstIndex(of: idx)! + 1)")
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)
                                : nil
                        )
                }
                .buttonStyle(.plain)
                .disabled(engine.phase != .recalling)
            }
        }
        .frame(maxWidth: 240)
    }

    private func scheduleBlockPresentation(engine: CorsiBlockEngine) {
        let ms = engine.config.presentationMs
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(ms)) {
            guard engine.phase == .presenting else { return }
            if !engine.advancePresentingBlock() {
                engine.finishPresenting()
                userInput = []
            }
        }
    }

    private func recallingControls(engine: CorsiBlockEngine) -> some View {
        HStack(spacing: 16) {
            Button {
                if !userInput.isEmpty { userInput.removeLast() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "delete.left")
                    Text("撤销")
                }
                .font(.system(.callout, design: .rounded, weight: .medium))
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Capsule().fill(BDColor.error.opacity(0.12)))
                .foregroundStyle(BDColor.error)
            }
            .buttonStyle(.plain)
            .disabled(userInput.isEmpty)

            Button {
                coordinator.submitResponse(userInput)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                    Text("确认")
                }
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Capsule().fill(BDColor.corsiBlockAccent))
            }
            .buttonStyle(.plain)
            .disabled(userInput.isEmpty)
        }
    }

    private func feedbackView(correct: Bool, engine: CorsiBlockEngine) -> some View {
        VStack(spacing: 12) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(correct ? BDColor.green : BDColor.error)

            Button("继续") {
                userInput = []
                if let result = coordinator.advanceAfterFeedback() {
                    appModel.recordCorsiBlockResult(result)
                }
            }
            .font(.system(.callout, design: .rounded, weight: .semibold))
            .buttonStyle(.bordered)
        }
    }

    private func resultView(metrics: CorsiBlockMetrics) -> some View {
        VStack(spacing: 20) {
            Text("空间广度完成")
                .font(.system(.title2, design: .rounded, weight: .bold))
            HStack(spacing: 16) {
                CBResultCard(label: "最大广度", value: "\(metrics.maxSpan)", color: BDColor.corsiBlockAccent)
                CBResultCard(label: "正确率", value: "\(Int(metrics.accuracy * 100))%", color: BDColor.green)
                CBResultCard(label: "位置错误", value: "\(metrics.positionErrors)", color: BDColor.warm)
            }
            .frame(maxWidth: 400)

            Button("关闭") { appModel.dismissCorsiBlockResult() }
                .buttonStyle(.bordered)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct CBResultCard: View {
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
