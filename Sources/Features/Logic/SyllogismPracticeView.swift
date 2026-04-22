import SwiftUI

struct SyllogismPracticeView: View {
    @Environment(AppModel.self) private var appModel
    let lessonGroup: Int

    @State private var currentTrial: SyllogismTrial?
    @State private var trialIndex: Int = 0
    @State private var showFeedback: Bool = false
    @State private var lastCorrect: Bool = false
    @State private var practiceResults: [SyllogismTrialResult] = []
    @State private var completed: Bool = false

    private let totalTrials = 5
    private var lesson: SyllogismLesson { SyllogismLessonBank.lesson(lessonGroup) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                if completed {
                    completionView
                } else if showFeedback, let trial = currentTrial {
                    feedbackContent(trial: trial)
                } else if let trial = currentTrial {
                    trialContent(trial: trial)
                } else {
                    readyView
                }
            }
            .padding(24)
            .frame(maxWidth: 700, alignment: .center)
            .frame(maxWidth: .infinity)
        }
        .onAppear { generateTrial() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("引导练习 · \(lesson.title)")
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(BDColor.textPrimary)
                Text("不限时间，认真思考每道题")
                    .font(.system(.callout))
                    .foregroundStyle(BDColor.textSecondary)
            }
            Spacer()
            Text("\(trialIndex + 1) / \(totalTrials)")
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(BDColor.textSecondary)
        }
    }

    private var readyView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("生成题目中...")
                .foregroundStyle(BDColor.textSecondary)
        }
        .padding(40)
    }

    // MARK: - Trial

    private func trialContent(trial: SyllogismTrial) -> some View {
        VStack(spacing: 24) {
            // Type badge
            HStack {
                InfoPill(title: trial.type.category.displayName, accent: BDColor.syllogismAccent)
                Spacer()
            }

            // Premises & conclusion
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(trial.premises.enumerated()), id: \.offset) { i, p in
                    HStack(alignment: .top, spacing: 12) {
                        Text("前提\(i+1)")
                            .font(.system(.caption, weight: .bold))
                            .foregroundStyle(BDColor.syllogismAccent)
                            .frame(width: 48, alignment: .trailing)
                        Text(p)
                            .font(.system(.body))
                            .foregroundStyle(BDColor.textPrimary)
                    }
                }
                Divider().padding(.vertical, 4)
                HStack(alignment: .top, spacing: 12) {
                    Text("结论")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(.orange)
                        .frame(width: 48, alignment: .trailing)
                    Text(trial.conclusion)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(BDColor.textPrimary)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(BDColor.panelSecondaryFill))

            // Response buttons
            HStack(spacing: 24) {
                Button { respond(valid: true) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("有效")
                    }
                }
                .buttonStyle(BDPrimaryButton(accent: .green))

                Button { respond(valid: false) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                        Text("无效")
                    }
                }
                .buttonStyle(BDSecondaryButton(accent: BDColor.error))
            }
        }
        .bdPanelSurface(.primary, cornerRadius: 14)
        .padding(.horizontal, 8)
    }

    // MARK: - Feedback

    private func feedbackContent(trial: SyllogismTrial) -> some View {
        VStack(spacing: 20) {
            Image(systemName: lastCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(lastCorrect ? .green : .red)

            Text(lastCorrect ? "正确！" : "不正确")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(BDColor.textPrimary)

            // Always show explanation
            VStack(alignment: .leading, spacing: 8) {
                Text(trial.explanation)
                    .font(.system(.body))
                    .foregroundStyle(BDColor.textPrimary)

                if !trial.detailedExplanation.isEmpty {
                    Divider()
                    Text(trial.detailedExplanation)
                        .font(.system(.callout))
                        .foregroundStyle(BDColor.textSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(BDColor.panelSecondaryFill))

            // Review button (only on wrong answers)
            if !lastCorrect {
                Button {
                    appModel.syllogismCoord.startLearning(lessonGroup: lessonGroup)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "book.fill")
                        Text("回顾该知识点")
                    }
                }
                .buttonStyle(BDSecondaryButton(accent: BDColor.syllogismAccent))
            }

            Button("继续") {
                showFeedback = false
                trialIndex += 1
                if trialIndex >= totalTrials {
                    completed = true
                    appModel.syllogismCoord.updateTypeStats(from: practiceResults)
                } else {
                    generateTrial()
                }
            }
            .buttonStyle(BDPrimaryButton(accent: BDColor.syllogismAccent))
        }
        .bdPanelSurface(.primary, cornerRadius: 14)
        .padding(.horizontal, 8)
    }

    // MARK: - Completion

    private var completionView: some View {
        let correct = practiceResults.filter(\.isCorrect).count
        return VStack(spacing: 20) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 48))
                .foregroundStyle(BDColor.syllogismAccent)

            Text("练习完成！")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(BDColor.textPrimary)

            Text("\(correct)/\(totalTrials) 正确")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(correct == totalTrials ? .green : BDColor.syllogismAccent)

            HStack(spacing: 12) {
                Button("再做几题") {
                    trialIndex = 0
                    practiceResults = []
                    completed = false
                    generateTrial()
                }
                .buttonStyle(BDSecondaryButton(accent: BDColor.syllogismAccent))

                Button("进入正式训练") {
                    let state = appModel.adaptiveState(for: .syllogism)
                    appModel.syllogismCoord.startSession(adaptiveState: state)
                }
                .buttonStyle(BDPrimaryButton(accent: BDColor.syllogismAccent))
            }
        }
        .bdPanelSurface(.primary, cornerRadius: 14)
        .padding(.horizontal, 8)
    }

    // MARK: - Logic

    private func generateTrial() {
        let types = lesson.types
        guard let type = types.randomElement() else { return }
        let engine = SyllogismEngine(difficulty: lesson.difficulty, totalTrials: 1)
        currentTrial = engine.buildTrial(type: type)
    }

    private func respond(valid: Bool) {
        guard let trial = currentTrial else { return }
        let correct = (valid == trial.isValid)
        lastCorrect = correct
        practiceResults.append(SyllogismTrialResult(
            trialIndex: trialIndex,
            trial: trial,
            userAnswer: valid,
            isCorrect: correct,
            reactionTime: nil,
            usedHint: false
        ))
        showFeedback = true
    }
}
