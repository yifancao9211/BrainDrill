import Foundation
import OpenAI

struct AIClient: Sendable {
    let baseURL: String
    let apiKey: String
    let model: String
    let maxRetries: Int

    init(baseURL: String, apiKey: String, model: String, maxRetries: Int = 3) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.maxRetries = maxRetries
    }

    func requestJSON<T: Decodable & Sendable>(
        system: String,
        user: String,
        responseType: T.Type,
        stage: String,
        toolSchemaJSON: String? = nil
    ) async throws -> AIClientResult<T> {
        var logs: [String] = ["AIClient 开始请求：\(stage)", "模型：\(model)"]
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                let (text, requestLogs) = try await performOpenAIRequest(system: system, user: user, toolSchemaJSON: toolSchemaJSON)
                logs.append(contentsOf: requestLogs)
                let decoded: T = try decodeJSONResponse(from: text, stage: stage, logs: &logs)
                return AIClientResult(value: decoded, logs: logs)
            } catch {
                lastError = error
                logs.append("第 \(attempt) 次尝试失败：\(error.localizedDescription)")
                if attempt < maxRetries {
                    let delayMs = 1000 * Int(pow(2.0, Double(attempt - 1)))
                    logs.append("等待 \(delayMs)ms 后重试...")
                    try? await Task.sleep(for: .milliseconds(delayMs))
                }
            }
        }

        throw MaterialsPipelineError.unsupportedAIResponse(logs: logs + [
            "\(stage) 在 \(maxRetries) 次尝试后仍然失败：\(lastError?.localizedDescription ?? "未知错误")"
        ])
    }

    // MARK: - OpenAI API Request

    private func performOpenAIRequest(system: String, user: String, toolSchemaJSON: String?) async throws -> (String, [String]) {
        let host = try resolvedHost()
        let configuration = OpenAI.Configuration(
            token: apiKey,
            host: host.host,
            port: host.port ?? 443,
            scheme: host.scheme,
            timeoutInterval: 90
        )
        let openAI = OpenAI(configuration: configuration)

        var tools: [ChatQuery.ChatCompletionToolParam]? = nil
        var toolChoice: ChatQuery.ChatCompletionFunctionCallOptionParam? = nil
        var responseFormat: ChatQuery.ResponseFormat? = .jsonObject

        if let schemaStr = toolSchemaJSON {
            let toolsRaw = """
            [
              {
                "type": "function",
                "function": {
                  "name": "submit_extracted_json",
                  "description": "提交提取或生成的标准 JSON",
                  "parameters": \(schemaStr),
                  "strict": true
                }
              }
            ]
            """
            if let data = toolsRaw.data(using: .utf8),
               let parsedTools = try? JSONDecoder().decode([ChatQuery.ChatCompletionToolParam].self, from: data) {
                tools = parsedTools
                toolChoice = try? JSONDecoder().decode(ChatQuery.ChatCompletionFunctionCallOptionParam.self, from: """
                {"type": "function", "function": {"name": "submit_extracted_json"}}
                """.data(using: .utf8)!)
                responseFormat = nil
            }
        }

        let query = ChatQuery(
            messages: [
                .system(.init(content: .textContent(system))),
                .user(.init(content: .string(user)))
            ],
            model: model,
            maxCompletionTokens: 16_384,
            responseFormat: responseFormat,
            temperature: 0.2,
            toolChoice: toolChoice,
            tools: tools
        )

        let result = try await openAI.chats(query: query)

        guard let choice = result.choices.first else {
            throw MaterialsPipelineError.missingAIText(logs: ["OpenAI 响应没有 choices"])
        }

        var finalExtractedText: String? = nil
        
        if let toolCalls = choice.message.toolCalls, let firstCall = toolCalls.first {
            finalExtractedText = firstCall.function.arguments
        } else if let content = choice.message.content {
            finalExtractedText = content
        }

        guard let text = finalExtractedText,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MaterialsPipelineError.missingAIText(logs: ["OpenAI 返回文本为空或 Function Arguments 解析失败"])
        }

        let finishReason = choice.finishReason
        var logs = [
            "OpenAI SDK 请求成功",
            "finish_reason: \(finishReason)",
            "响应长度：\(text.count) 字符",
            "响应片段：\(String(text.prefix(200)).replacingOccurrences(of: "\n", with: " "))"
        ]

        if finishReason == "length" {
            logs.append("⚠️ 响应因 max_tokens 被截断（finish_reason=length），输出可能不完整")
        }

        return (text, logs)
    }

    // MARK: - JSON Decoding

    private func decodeJSONResponse<T: Decodable>(from rawText: String, stage: String, logs: inout [String]) throws -> T {
        let sanitized = sanitizeJSONEnvelope(from: rawText)

        // Attempt 1: Direct decode
        if let decoded: T = tryDecode(sanitized) {
            logs.append("\(stage) JSON 直接解码成功")
            return decoded
        }

        // Attempt 2: Extract from first { to last }
        guard let firstBrace = sanitized.firstIndex(of: "{") else {
            throw MaterialsPipelineError.unsupportedAIResponse(logs: logs + [
                "\(stage) 未找到 JSON 对象",
                "原始响应片段：\(String(sanitized.prefix(300)))"
            ])
        }

        let fromBrace = String(sanitized[firstBrace...])
        if let decoded: T = tryDecode(fromBrace) {
            logs.append("\(stage) JSON 从首 { 解码成功")
            return decoded
        }

        // Attempt 3: Extract between first { and last }
        if let lastBrace = fromBrace.lastIndex(of: "}") {
            let objectString = String(fromBrace[...lastBrace])
            if let decoded: T = tryDecode(objectString) {
                logs.append("\(stage) JSON 提取 {…} 解码成功")
                return decoded
            }
        }

        // Attempt 4: Repair truncated JSON
        let repaired = repairTruncatedJSON(fromBrace)
        if let decoded: T = tryDecode(repaired) {
            logs.append("\(stage) JSON 修复后解码成功")
            return decoded
        }

        // All attempts failed
        let finalText: String
        if let lastBrace = fromBrace.lastIndex(of: "}") {
            finalText = String(fromBrace[...lastBrace])
        } else {
            finalText = repaired
        }

        guard let data = finalText.data(using: .utf8) else {
            throw MaterialsPipelineError.unsupportedAIResponse(logs: logs + [
                "\(stage) UTF-8 编码失败"
            ])
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logs.append("\(stage) JSON 解码失败：\(error.localizedDescription)")
            throw MaterialsPipelineError.unsupportedAIResponse(logs: logs + [
                "响应长度：\(rawText.count) 字符",
                "提取片段（头）：\(String(finalText.prefix(300)).replacingOccurrences(of: "\n", with: " "))",
                "提取片段（尾）：\(String(finalText.suffix(300)).replacingOccurrences(of: "\n", with: " "))"
            ])
        }
    }

    private func tryDecode<T: Decodable>(_ text: String) -> T? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func sanitizeJSONEnvelope(from rawText: String) -> String {
        var text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacingOccurrences(of: #"`{3,}(?:json)?\s*\n?"#, with: "", options: .regularExpression)
        if text.lowercased().hasPrefix("json") {
            text = text.replacingOccurrences(of: #"^(?i:json)\s*"#, with: "", options: .regularExpression)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func repairTruncatedJSON(_ text: String) -> String {
        var braceDepth = 0
        var bracketDepth = 0
        var inString = false
        var escaped = false
        for ch in text {
            if escaped { escaped = false; continue }
            if ch == "\\" && inString { escaped = true; continue }
            if ch == "\"" { inString.toggle(); continue }
            guard !inString else { continue }
            switch ch {
            case "{": braceDepth += 1
            case "}": braceDepth -= 1
            case "[": bracketDepth += 1
            case "]": bracketDepth -= 1
            default: break
            }
        }
        guard inString || bracketDepth > 0 || braceDepth > 0 else { return text }
        var result = text
        if inString { result += "\"" }
        for _ in 0..<max(bracketDepth, 0) { result += "]" }
        for _ in 0..<max(braceDepth, 0) { result += "}" }
        return result
    }

    // MARK: - Host Resolution

    private struct ResolvedHost {
        let host: String
        let port: Int?
        let scheme: String
    }

    private func resolvedHost() throws -> ResolvedHost {
        guard let url = URL(string: baseURL) else {
            throw MaterialsPipelineError.invalidBaseURL
        }

        var host = url.host ?? "localhost"
        let scheme = url.scheme ?? "https"
        let port = url.port

        // Strip path suffixes if user pasted full endpoint URL
        let path = url.path.lowercased()
        if path.contains("/v1/") || path.contains("/chat/") || path.contains("/messages") {
            // Use just host:port, the SDK handles path construction
        }

        // If the URL has a non-standard path prefix (like /v1 proxy), include it in host
        let cleanPath = url.path
            .replacingOccurrences(of: #"/v1/chat/completions$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"/v1/messages$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"/chat/completions$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"/messages$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"/v1$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if !cleanPath.isEmpty {
            host = "\(host)/\(cleanPath)"
        }

        return ResolvedHost(host: host, port: port, scheme: scheme)
    }
}

struct AIClientResult<T: Sendable>: Sendable {
    let value: T
    let logs: [String]
}
