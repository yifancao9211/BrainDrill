import Foundation

protocol AIProvider: Sendable {
    func complete(prompt: String) async throws -> String
}

struct LiteLLMProvider: AIProvider, Sendable {
    let baseURL: String
    let apiKey: String
    let model: String

    init(baseURL: String = "https://litellm.qa.domio.so", apiKey: String = "sk-3AXEzLuCihLJH9gDIXV6Lw", model: String = "claude-sonnet-4-20250514") {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
    }

    func complete(prompt: String) async throws -> String {
        let messages: [[String: String]] = [
            ["role": "user", "content": prompt]
        ]
        return try await chatCompletion(messages: messages.map { $0 as [String: Any] }, tools: nil)
    }

    func chatWithTools(messages: [[String: Any]], sessions: [SessionResult]) async throws -> (content: String, messages: [[String: Any]]) {
        var allMessages = messages
        let maxRounds = 5

        for _ in 0..<maxRounds {
            let response = try await rawChatCompletion(messages: allMessages, tools: AIToolDefinitions.tools)

            guard let choice = (response["choices"] as? [[String: Any]])?.first,
                  let message = choice["message"] as? [String: Any] else {
                throw AIError.invalidResponse
            }

            let finishReason = choice["finish_reason"] as? String ?? ""

            if let toolCalls = message["tool_calls"] as? [[String: Any]], !toolCalls.isEmpty {
                var assistantMsg: [String: Any] = ["role": "assistant"]
                if let content = message["content"] as? String { assistantMsg["content"] = content }
                assistantMsg["tool_calls"] = toolCalls
                allMessages.append(assistantMsg)

                for toolCall in toolCalls {
                    guard let function = toolCall["function"] as? [String: Any],
                          let callId = toolCall["id"] as? String,
                          let name = function["name"] as? String else { continue }

                    var args: [String: Any] = [:]
                    if let argsStr = function["arguments"] as? String,
                       let argsData = argsStr.data(using: .utf8),
                       let parsed = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {
                        args = parsed
                    }

                    let result = AIToolExecutor.execute(name: name, arguments: args, sessions: sessions)
                    allMessages.append([
                        "role": "tool",
                        "tool_call_id": callId,
                        "content": result
                    ])
                }
                continue
            }

            let content = message["content"] as? String ?? ""
            if !content.isEmpty || finishReason == "stop" {
                return (content, allMessages)
            }
        }

        throw AIError.maxRoundsExceeded
    }

    private func chatCompletion(messages: [[String: Any]], tools: [[String: Any]]?) async throws -> String {
        let response = try await rawChatCompletion(messages: messages, tools: tools)
        guard let choices = response["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.invalidResponse
        }
        return content
    }

    private func rawChatCompletion(messages: [[String: Any]], tools: [[String: Any]]?) async throws -> [String: Any] {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 2048
        ]
        if let tools, !tools.isEmpty {
            body["tools"] = tools
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        if let http = httpResponse as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw AIError.httpError(http.statusCode, body)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.invalidResponse
        }
        return json
    }
}

enum AIError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int, String)
    case maxRoundsExceeded

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "AI 返回格式异常"
        case let .httpError(code, body): "HTTP \(code): \(body.prefix(200))"
        case .maxRoundsExceeded: "AI 工具调用轮次超限"
        }
    }
}
