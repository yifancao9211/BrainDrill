import Foundation

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: ChatRole
    let content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: ChatRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

enum ChatRole: String, Codable, Equatable {
    case user
    case assistant
}

struct ChatHistory: Codable {
    var messages: [ChatMessage]
    var version: Int = 1

    init(messages: [ChatMessage] = []) {
        self.messages = messages
    }

    mutating func append(_ message: ChatMessage) {
        messages.append(message)
        if messages.count > 100 {
            messages = Array(messages.suffix(100))
        }
    }

    mutating func clear() {
        messages = []
    }
}
