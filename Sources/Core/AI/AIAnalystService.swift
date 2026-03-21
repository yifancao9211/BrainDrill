import Foundation

final class AIAnalystService: @unchecked Sendable {
    private var provider: LiteLLMProvider
    private var conversationMessages: [[String: Any]] = []
    private let queue = DispatchQueue(label: "ai.analyst.sync")

    private let systemPrompt = """
    你是 BrainDrill 的 AI 认知训练教练。你可以通过工具查询用户的训练数据，给出专业、具体的分析和建议。

    你的能力：
    - 分析用户的认知画像（5个维度：记忆容量、反应速度、抑制控制、视觉搜索、视觉工作记忆）
    - 查看各模块的训练历史和趋势
    - 检测异常表现和疲劳状态
    - 推荐最适合的训练计划
    - 分析最佳训练时段

    注意：
    - 用中文回答
    - 给出具体数据支撑的建议，不要空泛
    - 如果数据不足，如实说明
    - 不要宣称能提升智力，只说改善特定认知能力
    """

    init(baseURL: String = "https://litellm.qa.domio.so", apiKey: String = "sk-3AXEzLuCihLJH9gDIXV6Lw") {
        self.provider = LiteLLMProvider(baseURL: baseURL, apiKey: apiKey)
    }

    func updateProvider(baseURL: String, apiKey: String) {
        queue.sync { provider = LiteLLMProvider(baseURL: baseURL, apiKey: apiKey) }
    }

    func sendMessage(_ text: String, sessions: [SessionResult]) async throws -> String {
        let (messagesToSend, p) = queue.sync { () -> ([[String: Any]], LiteLLMProvider) in
            if conversationMessages.isEmpty {
                conversationMessages.append(["role": "system", "content": systemPrompt])
            }
            conversationMessages.append(["role": "user", "content": text])
            return (conversationMessages, provider)
        }

        let (response, updatedMessages) = try await p.chatWithTools(
            messages: messagesToSend,
            sessions: sessions
        )

        queue.sync {
            conversationMessages = updatedMessages
            conversationMessages.append(["role": "assistant", "content": response])
            trimHistory()
        }

        return response
    }

    func clearHistory() {
        queue.sync { conversationMessages = [] }
    }

    private func trimHistory() {
        let nonSystem = conversationMessages.filter { ($0["role"] as? String) != "system" }
        if nonSystem.count > 40 {
            let system = conversationMessages.first { ($0["role"] as? String) == "system" }
            let recent = Array(nonSystem.suffix(30))
            conversationMessages = (system.map { [$0] } ?? []) + recent
        }
    }
}
