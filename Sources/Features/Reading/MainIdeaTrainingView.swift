import SwiftUI

struct MainIdeaTrainingView: View {
    @Environment(AppModel.self) private var appModel

    @State private var passage: ReadingPassage?
    @State private var readingStartedAt: Date?
    @State private var answeringStartedAt: Date?
    @State private var selectedIndex: Int?
    @State private var generatedSummary = ""
    @State private var summaryLocked = false
    @State private var lastMetrics: MainIdeaMetrics?

    private let accent = BDColor.gold

    var body: some View {
        BDWorkbenchPage(title: "主旨提取", subtitle: "先主动生成一句主旨，再进入识别判断。") {
            if let passage {
                PassageStage(passage: passage, accent: accent) {
                    if answeringStartedAt == nil {
                        Button("我读完了，开始提炼主旨") {
                            answeringStartedAt = Date()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        answerStage(for: passage)
                    }
                }

                if let lastMetrics {
                    resultCard(metrics: lastMetrics, passage: passage)
                }
            } else {
                ReadingModuleIntroCard(
                    title: "抓主旨",
                    subtitle: "从被动识别改成主动概括，避免把局部细节误当全文结论。",
                    stats: [
                        ("累计次数", "\(sessionCount)", accent),
                        ("识别正确率", accuracyLabel, BDColor.green),
                        ("关键词覆盖", keywordCoverageLabel, BDColor.warm),
                    ],
                    accent: accent,
                    actionTitle: "开始一篇短文"
                ) {
                    startNewSession()
                }
            }
        }
    }

    private var relevantSessions: [SessionResult] {
        appModel.sessions.filter { $0.module == .mainIdea }
    }

    private var sessionCount: Int { relevantSessions.count }

    private var accuracyLabel: String {
        let metrics = relevantSessions.compactMap(\.mainIdeaMetrics)
        guard !metrics.isEmpty else { return "--" }
        let correct = metrics.filter(\.isCorrect).count
        return "\(Int((Double(correct) / Double(metrics.count)) * 100))%"
    }

    private var keywordCoverageLabel: String {
        let metrics = relevantSessions.compactMap(\.mainIdeaMetrics)
        guard !metrics.isEmpty else { return "--" }
        let average = metrics.map(\.keywordCoverage).reduce(0, +) / Double(metrics.count)
        return "\(Int(average * 100))%"
    }

    @ViewBuilder
    private func answerStage(for passage: ReadingPassage) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SurfaceCard(
                title: "先写一句主旨",
                subtitle: "难度 \(passage.difficulty)：至少写 \(passage.mainIdeaMinimumLength) 个字，再用选项校准自己。"
            ) {
                ReadingPromptEditor(
                    title: "你的主旨句",
                    subtitle: "尽量覆盖主题对象、关键关系和作者真正想表达的结论。",
                    placeholder: "例如：先写清楚“是什么对象，在什么关系下，得出什么结论”。",
                    text: $generatedSummary
                )

                HStack {
                    Text("当前字数 \(summaryCharacterCount)")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(summaryCharacterCount >= passage.mainIdeaMinimumLength ? BDColor.green : BDColor.textSecondary)
                    Spacer()
                    Button(summaryLocked ? "重新编辑" : "锁定主旨句") {
                        summaryLocked.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!summaryLocked && summaryCharacterCount < passage.mainIdeaMinimumLength)
                }
            }

            if summaryLocked {
                SurfaceCard(title: "再做识别校准", subtitle: "判断哪一句最贴近整篇主旨，而不是局部事实。") {
                    Text(generatedSummary)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(BDColor.textPrimary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(accent.opacity(0.1))
                        )

                    ForEach(Array(passage.mainIdeaOptions.enumerated()), id: \.offset) { index, option in
                        ReadingOptionButton(title: option, isSelected: selectedIndex == index, accent: accent) {
                            selectedIndex = index
                        }
                    }

                    Button("提交") {
                        submit()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedIndex == nil)
                }
            }
        }
    }

    @ViewBuilder
    private func resultCard(metrics: MainIdeaMetrics, passage: ReadingPassage) -> some View {
        SurfaceCard(title: metrics.isCorrect ? "主旨抓准了" : "主旨判断偏了", subtitle: "先看生成质量，再看识别是否命中。") {
            HStack(spacing: 12) {
                MetricTile(label: "识别结果", value: metrics.isCorrect ? "正确" : "偏差", accent: metrics.isCorrect ? BDColor.green : BDColor.error)
                MetricTile(label: "关键词覆盖", value: "\(metrics.matchedKeywordCount)/\(metrics.totalKeywordCount)", accent: accent)
                MetricTile(label: "作答耗时", value: appModel.formattedDuration(metrics.responseDuration), accent: BDColor.warm)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("你的主旨句")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(BDColor.textSecondary)
                Text(metrics.generatedSummary)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(BDColor.textPrimary)
                Text("标准主旨：\(passage.mainIdeaRubric.idealSummary)")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(BDColor.textSecondary)
                Text("反馈：\(feedbackLine(for: metrics, passage: passage))")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(BDColor.textSecondary)
            }

            Button("再来一篇") {
                startNewSession()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var summaryCharacterCount: Int {
        generatedSummary
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .count
    }

    private func startNewSession() {
        passage = ReadingDifficultyPlanner.nextPassage(for: .mainIdea, sessions: appModel.sessions)
        readingStartedAt = Date()
        answeringStartedAt = nil
        selectedIndex = nil
        generatedSummary = ""
        summaryLocked = false
        lastMetrics = nil
    }

    private func submit() {
        guard let passage, let selectedIndex, let readingStartedAt, let answeringStartedAt else { return }
        let now = Date()
        let matchedKeywordCount = matchingKeywordCount(in: generatedSummary, keywords: passage.mainIdeaRubric.keywords)
        let metrics = MainIdeaMetrics(
            passageID: passage.id,
            difficulty: passage.difficulty,
            isCorrect: selectedIndex == passage.mainIdeaAnswerIndex,
            selectedIndex: selectedIndex,
            generatedSummary: generatedSummary.trimmingCharacters(in: .whitespacesAndNewlines),
            matchedKeywordCount: matchedKeywordCount,
            totalKeywordCount: passage.mainIdeaRubric.keywords.count,
            readingDuration: answeringStartedAt.timeIntervalSince(readingStartedAt),
            responseDuration: now.timeIntervalSince(answeringStartedAt)
        )
        appModel.recordMainIdeaResult(metrics, startedAt: readingStartedAt, endedAt: now)
        lastMetrics = metrics
        self.passage = passage
    }

    private func matchingKeywordCount(in text: String, keywords: [String]) -> Int {
        let normalized = normalizedText(text)
        return keywords.filter { normalized.contains(normalizedText($0)) }.count
    }

    private func normalizedText(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }

    private func feedbackLine(for metrics: MainIdeaMetrics, passage: ReadingPassage) -> String {
        if metrics.keywordCoverage >= 0.8, metrics.isCorrect {
            return "你已经把对象、关系和总结论都压缩进一句话里了。"
        }

        if metrics.keywordCoverage < 0.5 {
            return "你的概括里缺了关键关系词。\(passage.mainIdeaRubric.trapNote)"
        }

        if !metrics.isCorrect {
            return passage.mainIdeaRubric.trapNote
        }

        return "识别是对的，但一句主旨里还可以再压缩得更完整。"
    }
}
