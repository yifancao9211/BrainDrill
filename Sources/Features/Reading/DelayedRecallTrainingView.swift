import SwiftUI

struct DelayedRecallTrainingView: View {
    private enum Phase {
        case intro
        case reading
        case distractor
        case freeRecall
        case cuedRecall
        case result
    }

    private enum FocusTarget: Hashable {
        case intro
        case startDistractor
        case freeRecallContinue
        case submitRecall
        case restart
    }

    private struct DistractorQuestion: Identifiable {
        let id: String
        let prompt: String
        let options: [String]
        let answerIndex: Int
    }

    @Environment(AppModel.self) private var appModel

    @State private var phase: Phase = .intro
    @State private var passage: ReadingPassage?
    @State private var startedAt: Date?
    @State private var distractorStartedAt: Date?
    @State private var recallStartedAt: Date?
    @State private var distractorQuestions: [DistractorQuestion] = []
    @State private var currentDistractorIndex = 0
    @State private var distractorCorrectCount = 0
    @State private var selectedPromptIDs: Set<String> = []
    @State private var freeRecallDraft = ""
    @State private var lastMetrics: DelayedRecallMetrics?
    @FocusState private var focusedTarget: FocusTarget?

    private let accent = BDColor.green

    var body: some View {
        BDWorkbenchPage(title: "延迟回忆", subtitle: "把回忆拆成无提示提取和有提示校准两段。") {
            switch phase {
            case .intro:
                ReadingModuleIntroCard(
                    title: "读后提取",
                    subtitle: "先拉长延迟，再做无提示回忆，最后用结构化线索校准自己。",
                    stats: [
                        ("累计次数", "\(sessionCount)", accent),
                        ("提示命中率", accuracyLabel, BDColor.green),
                        ("自由回忆覆盖", freeRecallCoverageLabel, BDColor.warm),
                    ],
                    accent: accent,
                    actionTitle: "开始一轮回忆"
                ) {
                    startNewSession()
                }
                .onAppear {
                    focusedTarget = .intro
                }
            case .reading:
                if let passage {
                    PassageStage(passage: passage, accent: accent) {
                        Button("进入干扰阶段") {
                            startDistractor()
                        }
                        .buttonStyle(BDPrimaryButton(accent: accent))
                        .keyboardShortcut(.defaultAction)
                        .focused($focusedTarget, equals: .startDistractor)
                    }
                }
            case .distractor:
                distractorCard
            case .freeRecall:
                if let passage {
                    freeRecallCard(for: passage)
                }
            case .cuedRecall:
                if let passage {
                    cuedRecallCard(for: passage)
                }
            case .result:
                if let passage, let lastMetrics {
                    resultCard(metrics: lastMetrics, passage: passage)
                }
            }
        }
        .onChange(of: phase) { _, newPhase in
            switch newPhase {
            case .intro:
                focusedTarget = .intro
            case .reading:
                focusedTarget = .startDistractor
            case .freeRecall:
                focusedTarget = .freeRecallContinue
            case .cuedRecall:
                focusedTarget = .submitRecall
            case .result:
                focusedTarget = .restart
            case .distractor:
                focusedTarget = nil
            }
        }
    }

    private var relevantSessions: [SessionResult] {
        appModel.sessions.filter { $0.module == .delayedRecall }
    }

    private var sessionCount: Int { relevantSessions.count }

    private var accuracyLabel: String {
        let metrics = relevantSessions.compactMap(\.delayedRecallMetrics)
        guard !metrics.isEmpty else { return "--" }
        let average = metrics.map(\.accuracy).reduce(0, +) / Double(metrics.count)
        return "\(Int(average * 100))%"
    }

    private var freeRecallCoverageLabel: String {
        let metrics = relevantSessions.compactMap(\.delayedRecallMetrics)
        guard !metrics.isEmpty else { return "--" }
        let average = metrics.map(\.freeRecallCoverage).reduce(0, +) / Double(metrics.count)
        return "\(Int(average * 100))%"
    }

    private var distractorCard: some View {
        BDTrainingStage(accent: accent) {
            VStack(spacing: 18) {
                Text("干扰阶段")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(BDColor.textPrimary)
                Text("先完成这些无关小题，把刚读过的表层痕迹拉开。")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(BDColor.textSecondary)

                Text("\(min(currentDistractorIndex + 1, max(distractorQuestions.count, 1)))/\(max(distractorQuestions.count, 1))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)

                if let question = distractorQuestions[safe: currentDistractorIndex] {
                    SurfaceCard(title: "干扰题 \(currentDistractorIndex + 1)/\(distractorQuestions.count)", subtitle: "快速判断，不要回想正文。") {
                        Text(question.prompt)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(BDColor.textPrimary)

                        ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                            ReadingOptionButton(title: option, isSelected: false, accent: accent) {
                                answerDistractor(index)
                            }
                        }
                    }
                } else {
                    Text("干扰题已经做完，正在进入回忆。")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(BDColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    @ViewBuilder
    private func freeRecallCard(for passage: ReadingPassage) -> some View {
        SurfaceCard(
            title: "先做无提示回忆",
            subtitle: "难度 \(passage.difficulty)：至少写 \(passage.freeRecallMinimumLength) 个字，先靠自己提取。"
        ) {
            ReadingPromptEditor(
                title: "你还记得的关键点",
                subtitle: "优先写机制、对比关系、限制条件，不要只写零散名词。",
                placeholder: "例如：对象是什么、作者真正对比或强调了什么、有什么限制。",
                text: $freeRecallDraft
            )

            HStack {
                Text("当前字数 \(freeRecallCharacterCount)")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(freeRecallCharacterCount >= passage.freeRecallMinimumLength ? BDColor.green : BDColor.textSecondary)
                Spacer()
                Button("进入提示回忆") {
                    phase = .cuedRecall
                }
                .buttonStyle(BDPrimaryButton(accent: accent))
                .disabled(freeRecallCharacterCount < passage.freeRecallMinimumLength)
                .keyboardShortcut(.defaultAction)
                .focused($focusedTarget, equals: .freeRecallContinue)
            }
        }
    }

    @ViewBuilder
    private func cuedRecallCard(for passage: ReadingPassage) -> some View {
        SurfaceCard(title: "再做提示回忆", subtitle: "从候选信息中选出真正关键的 \(targetCount(for: passage)) 条。") {
            VStack(spacing: 10) {
                ForEach(passage.recallPrompts) { prompt in
                    ReadingOptionButton(
                        title: prompt.text,
                        isSelected: selectedPromptIDs.contains(prompt.id),
                        accent: accent
                    ) {
                        togglePrompt(prompt.id)
                    }
                }
            }

            Button("提交回忆") {
                submitRecall()
            }
            .buttonStyle(BDPrimaryButton(accent: accent))
            .disabled(selectedPromptIDs.count != targetCount(for: passage))
            .keyboardShortcut(.defaultAction)
            .focused($focusedTarget, equals: .submitRecall)
        }
    }

    @ViewBuilder
    private func resultCard(metrics: DelayedRecallMetrics, passage: ReadingPassage) -> some View {
        SurfaceCard(title: "延迟回忆完成", subtitle: "先看自由提取，再看带提示下能不能校准到关键点。") {
            HStack(spacing: 12) {
                MetricTile(label: "自由回忆", value: "\(metrics.freeRecallKeywordHits)/\(metrics.freeRecallKeywordTotal)", accent: BDColor.warm)
                MetricTile(label: "提示命中", value: "\(metrics.recalledTargets)/\(metrics.totalTargets)", accent: accent)
                MetricTile(label: "延迟", value: "\(metrics.delaySeconds)秒", accent: BDColor.green)
            }

            Text("干扰题：\(metrics.distractorCorrectCount)/\(metrics.distractorQuestionCount) 题")
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(BDColor.textSecondary)
            Text("你的自由回忆：\(metrics.freeRecallText)")
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(BDColor.textPrimary)
            Text(resultFeedback(for: metrics, passage: passage))
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(BDColor.textSecondary)

            Button("再来一轮") {
                startNewSession()
            }
            .buttonStyle(BDPrimaryButton(accent: accent))
            .keyboardShortcut(.defaultAction)
            .focused($focusedTarget, equals: .restart)
        }
    }

    private func startNewSession() {
        passage = ReadingDifficultyPlanner.nextPassage(for: .delayedRecall, sessions: appModel.sessions)
        phase = .reading
        startedAt = Date()
        distractorStartedAt = nil
        recallStartedAt = nil
        distractorQuestions = []
        currentDistractorIndex = 0
        distractorCorrectCount = 0
        selectedPromptIDs = []
        freeRecallDraft = ""
        lastMetrics = nil
    }

    private func startDistractor() {
        guard let passage else { return }
        phase = .distractor
        distractorStartedAt = Date()
        distractorQuestions = makeDistractorQuestions(for: passage)
        currentDistractorIndex = 0
        distractorCorrectCount = 0
    }

    private func answerDistractor(_ selectedIndex: Int) {
        guard let question = distractorQuestions[safe: currentDistractorIndex] else { return }
        if selectedIndex == question.answerIndex {
            distractorCorrectCount += 1
        }
        currentDistractorIndex += 1
        if currentDistractorIndex >= distractorQuestions.count {
            phase = .freeRecall
            recallStartedAt = Date()
        }
    }

    private func togglePrompt(_ id: String) {
        if selectedPromptIDs.contains(id) {
            selectedPromptIDs.remove(id)
        } else if selectedPromptIDs.count < (passage.map(targetCount(for:)) ?? 0) {
            selectedPromptIDs.insert(id)
        }
    }

    private func targetCount(for passage: ReadingPassage) -> Int {
        passage.recallPrompts.filter(\.isTarget).count
    }

    private var freeRecallCharacterCount: Int {
        freeRecallDraft
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .count
    }

    private func submitRecall() {
        guard let passage, let startedAt, let recallStartedAt else { return }
        let now = Date()
        let targets = Set(passage.recallPrompts.filter(\.isTarget).map(\.id))
        let recalledTargets = selectedPromptIDs.intersection(targets).count
        let intrusionCount = selectedPromptIDs.subtracting(targets).count
        let freeRecallHits = matchingKeywordCount(in: freeRecallDraft, keywords: passage.recallKeywords)
        let actualDelaySeconds = Int(recallStartedAt.timeIntervalSince(distractorStartedAt ?? startedAt).rounded())
        let metrics = DelayedRecallMetrics(
            passageID: passage.id,
            difficulty: passage.difficulty,
            delaySeconds: actualDelaySeconds,
            totalTargets: targets.count,
            recalledTargets: recalledTargets,
            intrusionCount: intrusionCount,
            accuracy: Double(recalledTargets) / Double(max(targets.count, 1)),
            freeRecallText: freeRecallDraft.trimmingCharacters(in: .whitespacesAndNewlines),
            freeRecallKeywordHits: freeRecallHits,
            freeRecallKeywordTotal: passage.recallKeywords.count,
            distractorQuestionCount: distractorQuestions.count,
            distractorCorrectCount: distractorCorrectCount,
            responseDuration: now.timeIntervalSince(recallStartedAt)
        )
        appModel.recordDelayedRecallResult(metrics, startedAt: startedAt, endedAt: now)
        lastMetrics = metrics
        phase = .result
    }

    private func makeDistractorQuestions(for passage: ReadingPassage) -> [DistractorQuestion] {
        let level = passage.difficulty
        return (0..<passage.distractorQuestionCount).map { index in
            switch (level, index % 3) {
            case (1, _):
                let lhs = Int.random(in: 7...18)
                let rhs = Int.random(in: 2...8)
                let answer = lhs + rhs
                let options = [answer, answer + 2, max(answer - 2, 1)].shuffled()
                return DistractorQuestion(
                    id: "d\(index)",
                    prompt: "\(lhs) + \(rhs) = ?",
                    options: options.map(String.init),
                    answerIndex: options.firstIndex(of: answer) ?? 0
                )
            case (2, 0), (3, 0):
                let value = Int.random(in: 24...68)
                let answer = value - 7
                let options = [answer, answer - 3, answer + 4].shuffled()
                return DistractorQuestion(
                    id: "d\(index)",
                    prompt: "\(value) 减 7 等于多少？",
                    options: options.map(String.init),
                    answerIndex: options.firstIndex(of: answer) ?? 0
                )
            case (2, 1), (3, 1):
                let values = (0..<4).map { _ in Int.random(in: 10...99) }.sorted()
                let answer = values.last ?? 0
                let options = values.shuffled().map(String.init)
                return DistractorQuestion(
                    id: "d\(index)",
                    prompt: "下面哪一个数字最大？",
                    options: options,
                    answerIndex: options.firstIndex(of: String(answer)) ?? 0
                )
            default:
                let start = Int.random(in: 40...90)
                let answer = start - 14
                let options = [answer, answer - 7, answer + 7].shuffled()
                return DistractorQuestion(
                    id: "d\(index)",
                    prompt: "如果从 \(start) 开始连续减两次 7，结果是多少？",
                    options: options.map(String.init),
                    answerIndex: options.firstIndex(of: answer) ?? 0
                )
            }
        }
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

    private func resultFeedback(for metrics: DelayedRecallMetrics, passage: ReadingPassage) -> String {
        if metrics.freeRecallCoverage >= 0.8, metrics.accuracy >= 0.8 {
            return "你在延迟后仍能主动提取结构化信息，不只是靠选项提示。"
        }

        if passage.difficulty == 3, metrics.freeRecallCoverage < 0.5 {
            return "高难度下，你在无提示阶段掉得比较多。下一轮重点先回忆场景条件和限制条件。"
        }

        return "提示回忆还可以，但无提示阶段还不够稳，说明关键信息尚未压缩成自己的表征。"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
