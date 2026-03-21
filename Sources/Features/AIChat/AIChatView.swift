import SwiftUI

struct AIChatView: View {
    @Environment(AppModel.self) private var appModel
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            messageList
            Divider()
            quickActions
            inputBar
        }
        .frame(maxHeight: .infinity)
    }

    private var header: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(BDColor.teal)
            Text("AI 教练")
                .font(.system(.headline, design: .rounded))
            Spacer()
            Button {
                appModel.clearChat()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("清空对话")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if appModel.chatMessages.isEmpty {
                        emptyState
                    } else {
                        ForEach(appModel.chatMessages) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }
                    }

                    if appModel.isChatLoading {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("思考中...")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .id("loading")
                    }
                }
                .padding(12)
            }
            .onChange(of: appModel.chatMessages.count) { _, _ in
                withAnimation {
                    if let last = appModel.chatMessages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: appModel.isChatLoading) { _, loading in
                if loading {
                    withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(BDColor.teal.opacity(0.4))
            Text("问我任何关于训练的问题")
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.secondary)
            Text("我能分析你的表现、发现趋势、给出建议")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var quickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                QuickButton(title: "分析表现", icon: "chart.line.uptrend.xyaxis") {
                    appModel.sendQuickAnalysis()
                }
                QuickButton(title: "本周周报", icon: "doc.text") {
                    appModel.sendWeeklyReport()
                }
                QuickButton(title: "今天练什么", icon: "calendar") {
                    appModel.sendChatMessage("今天我应该练什么？帮我制定一个20分钟的训练计划。")
                }
                QuickButton(title: "我的弱项", icon: "exclamationmark.triangle") {
                    appModel.sendChatMessage("我哪个维度最弱？应该怎么针对性提升？")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .disabled(appModel.isChatLoading)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("输入问题...", text: $inputText)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded))
                .focused($inputFocused)
                .onSubmit { send() }

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(inputText.isEmpty ? Color.secondary.opacity(0.3) : BDColor.teal)
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty || appModel.isChatLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        appModel.sendChatMessage(text)
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(BDColor.teal)
                    .frame(width: 20, height: 20)
                    .padding(.top, 2)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(.body, design: .rounded))
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(message.role == .user ? BDColor.primaryBlue.opacity(0.12) : Color.primary.opacity(0.04))
                    )

                Text(timeString(message.timestamp))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        }
        .padding(.horizontal, 4)
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

private struct QuickButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(BDColor.teal.opacity(0.1)))
            .foregroundStyle(BDColor.teal)
        }
        .buttonStyle(.plain)
    }
}
