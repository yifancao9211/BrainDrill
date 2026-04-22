import SwiftUI

struct SyllogismLearningView: View {
    @Environment(AppModel.self) private var appModel
    let lessonGroup: Int

    @State private var selectedLesson: Int
    @State private var cardIndex: Int = 0

    init(lessonGroup: Int) {
        self.lessonGroup = lessonGroup
        self._selectedLesson = State(initialValue: lessonGroup)
    }

    private var allLessons: [SyllogismLesson] { SyllogismLessonBank.allLessons() }
    private var currentLesson: SyllogismLesson { SyllogismLessonBank.lesson(selectedLesson) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                lessonPicker
                if appModel.syllogismCoord.isLessonUnlocked(selectedLesson) {
                    cardContent
                    navigationButtons
                } else {
                    lockedView
                }
            }
            .padding(24)
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("逻辑快判 · 学习")
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(BDColor.textPrimary)
                Text("掌握每种推理类型的逻辑形式与常见陷阱")
                    .font(.system(.callout))
                    .foregroundStyle(BDColor.textSecondary)
            }
            Spacer()
            Button("返回") {
                appModel.syllogismCoord.mode = .idle
            }
            .buttonStyle(BDSecondaryButton(accent: BDColor.error))
        }
    }

    // MARK: - Lesson Picker

    private var lessonPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("课程列表")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(BDColor.textSecondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(allLessons) { lesson in
                    lessonCell(lesson: lesson)
                }
            }
        }
    }

    private func lessonCell(lesson: SyllogismLesson) -> some View {
        let completed = appModel.syllogismCoord.completedLessons.contains(lesson.id)
        let unlocked = appModel.syllogismCoord.isLessonUnlocked(lesson.id)
        let isSelected = selectedLesson == lesson.id
        let bgColor: Color = isSelected ? BDColor.syllogismAccent.opacity(0.15) : BDColor.panelSecondaryFill
        let borderColor: Color = isSelected ? BDColor.syllogismAccent : .clear

        return Button {
            if unlocked {
                selectedLesson = lesson.id
                cardIndex = 0
            }
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("L\(lesson.id)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                    if completed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                    } else if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(BDColor.textTertiary)
                    }
                }
                Text(lesson.title)
                    .font(.system(.caption2))
                    .lineLimit(1)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(bgColor))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(borderColor, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .opacity(unlocked ? 1 : 0.5)
    }

    // MARK: - Card Content

    @ViewBuilder
    private var cardContent: some View {
        let cards = currentLesson.cards
        if cardIndex < cards.count {
            let card = cards[cardIndex]
            VStack(alignment: .leading, spacing: 16) {
                // Title
                HStack {
                    Text(card.typeName)
                        .font(.system(.title3, weight: .bold))
                        .foregroundStyle(BDColor.textPrimary)
                    Spacer()
                    InfoPill(title: card.isValid ? "✅ 有效" : "❌ 无效", accent: card.isValid ? .green : .red)
                }

                // Logic form
                Text(card.logicForm)
                    .font(.system(.body, design: .monospaced, weight: .medium))
                    .foregroundStyle(BDColor.syllogismAccent)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(BDColor.syllogismAccent.opacity(0.08)))

                // Worked example
                VStack(alignment: .leading, spacing: 10) {
                    Text("日常例子")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(BDColor.textSecondary)

                    ForEach(Array(card.example.premises.enumerated()), id: \.offset) { i, p in
                        HStack(alignment: .top, spacing: 8) {
                            Text("前提\(i+1)")
                                .font(.system(.caption, weight: .bold))
                                .foregroundStyle(BDColor.syllogismAccent)
                                .frame(width: 44, alignment: .trailing)
                            Text(p)
                                .font(.system(.body))
                                .foregroundStyle(BDColor.textPrimary)
                        }
                    }
                    Divider()
                    HStack(alignment: .top, spacing: 8) {
                        Text("结论")
                            .font(.system(.caption, weight: .bold))
                            .foregroundStyle(.orange)
                            .frame(width: 44, alignment: .trailing)
                        Text(card.example.conclusion)
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(BDColor.textPrimary)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(BDColor.panelSecondaryFill))

                // Why explanation
                BDInsightCard(title: "为什么\(card.isValid ? "有效" : "无效")", bodyText: card.whyExplanation, accent: BDColor.syllogismAccent)

                // Confusion warning
                if let warning = card.confusionWarning {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text(warning)
                            .font(.system(.callout))
                            .foregroundStyle(BDColor.textSecondary)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.08)))
                }
            }
            .padding(20)
            .bdPanelSurface(.primary, cornerRadius: 14)
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        let cards = currentLesson.cards
        return HStack(spacing: 12) {
            if cardIndex > 0 {
                Button("上一个") { cardIndex -= 1 }
                    .buttonStyle(BDSecondaryButton(accent: BDColor.syllogismAccent))
            }
            Spacer()
            Text("\(cardIndex + 1) / \(cards.count)")
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(BDColor.textSecondary)
            Spacer()
            if cardIndex < cards.count - 1 {
                Button("下一个") { cardIndex += 1 }
                    .buttonStyle(BDPrimaryButton(accent: BDColor.syllogismAccent))
            } else {
                Button("完成学习 → 开始练习") {
                    appModel.syllogismCoord.markLessonCompleted(selectedLesson)
                    appModel.syllogismCoord.startPractice(lessonGroup: selectedLesson)
                }
                .buttonStyle(BDPrimaryButton(accent: .green))
            }
        }
    }

    private var lockedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundStyle(BDColor.textTertiary)
            Text("完成前置课程后解锁")
                .font(.system(.callout))
                .foregroundStyle(BDColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}
