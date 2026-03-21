import Foundation

enum AIToolDefinitions {
    nonisolated(unsafe) static let tools: [[String: Any]] = [
        makeTool(name: "get_cognitive_profile", description: "获取用户的5维认知画像分数(记忆容量/反应速度/抑制控制/视觉搜索/视觉工作记忆)，每个维度0-100分", parameters: [:]),
        makeTool(name: "get_module_history", description: "获取某个训练模块的最近N条训练记录，包含详细指标", parameters: [
            "module": ["type": "string", "description": "模块名: schulte/flanker/goNoGo/nBack/digitSpan/choiceRT/changeDetection/visualSearch/corsiBlock/stopSignal"],
            "limit": ["type": "integer", "description": "返回记录条数，默认5"]
        ]),
        makeTool(name: "get_performance_trend", description: "获取某个模块的表现趋势(进步/下降/平台期)", parameters: [
            "module": ["type": "string", "description": "模块名"]
        ]),
        makeTool(name: "get_anomalies", description: "检测最近训练中是否有异常表现(比正常水平偏离超过2个标准差)", parameters: [:]),
        makeTool(name: "get_fatigue_status", description: "评估用户当前的疲劳状态，基于最近的反应时趋势和正确率变化", parameters: [:]),
        makeTool(name: "get_time_of_day_analysis", description: "分析用户在不同时段(早晨/上午/下午/傍晚/夜晚)的训练表现，找出最佳训练时段", parameters: [:]),
        makeTool(name: "get_training_recommendations", description: "基于训练频率、表现趋势和均衡性，推荐今天应该练哪些模块", parameters: [:]),
        makeTool(name: "get_statistics", description: "获取全局训练统计摘要：各模块训练次数、最佳成绩、近期趋势", parameters: [:]),
    ]

    static var toolsJSON: Data {
        try! JSONSerialization.data(withJSONObject: tools)
    }

    private static func makeTool(name: String, description: String, parameters: [String: [String: String]]) -> [String: Any] {
        var properties: [String: Any] = [:]
        var required: [String] = []
        for (key, schema) in parameters {
            properties[key] = schema
            required.append(key)
        }

        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": properties,
                    "required": required
                ] as [String: Any]
            ] as [String: Any]
        ]
    }
}
