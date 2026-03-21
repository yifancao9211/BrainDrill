import Foundation
import Observation

@Observable
final class VisualSearchCoordinator {
    var engine: VisualSearchEngine?
    var statusMessage: String = "视觉搜索训练：在干扰物中找到目标。"
    var lastResult: SessionResult?

    var isActive: Bool { engine != nil && !(engine?.isComplete ?? true) }

    func startSession(settings: TrainingSettings) {
        let config = VisualSearchSessionConfig(
            setSizes: settings.visualSearchSetSizes,
            trialsPerSize: settings.visualSearchTrialsPerSize
        )
        engine = VisualSearchEngine(config: config)
        lastResult = nil
        if let target = engine?.target {
            statusMessage = "找到 \(colorName(target.color))\(shapeName(target.shape))"
        }
    }

    func handleResponse(userSaidPresent: Bool, at date: Date = Date()) -> SessionResult? {
        guard let engine else { return nil }
        _ = engine.recordResponse(userSaidPresent: userSaidPresent, at: date)
        engine.advanceToNext()
        if engine.isComplete {
            return buildResult()
        }
        return nil
    }

    func cancelSession() {
        engine = nil
        statusMessage = "已取消视觉搜索训练。"
    }

    private func buildResult() -> SessionResult? {
        guard let engine else { return nil }
        let metrics = engine.computeMetrics()
        let now = Date()
        let result = SessionResult(
            module: .visualSearch,
            startedAt: engine.startedAt,
            endedAt: now,
            duration: now.timeIntervalSince(engine.startedAt),
            metrics: .visualSearch(metrics)
        )
        lastResult = result
        statusMessage = "视觉搜索完成 — 搜索斜率 \(String(format: "%.0f", metrics.searchSlope * 1000))ms/项"
        self.engine = nil
        return result
    }

    private func colorName(_ color: SearchColor) -> String {
        switch color {
        case .red:   "红色"
        case .blue:  "蓝色"
        case .green: "绿色"
        }
    }

    private func shapeName(_ shape: SearchShape) -> String {
        switch shape {
        case .circle:   "圆形"
        case .square:   "方块"
        case .triangle: "三角"
        }
    }
}
