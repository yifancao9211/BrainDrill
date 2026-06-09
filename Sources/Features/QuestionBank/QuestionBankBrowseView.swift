import SwiftUI

/// 题库只读浏览（弹窗版）：包一层导航与「完成」按钮，内部复用 `QuestionBankBrowseList`。
struct QuestionBankBrowseView: View {
    let questions: [BankQuestion]
    let accent: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                QuestionBankBrowseList(questions: questions, accent: accent)
                    .padding(20)
                    .frame(maxWidth: 720, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("题库一览（\(questions.count) 题）")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
        .frame(minWidth: 560, minHeight: 520)
    }
}

/// 题库只读列表：按板块分组列出题目，展开看选项、正确答案与解析（图形题直接绘制）。
/// 不含外层滚动，供素材库内嵌或弹窗包装使用。
struct QuestionBankBrowseList: View {
    let questions: [BankQuestion]
    var accent: Color = BDColor.teal
    @State private var expanded: Set<String> = []

    private var sections: [BankSection] {
        BankSection.allCases.filter { sec in questions.contains { $0.section == sec } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(sections) { section in
                let items = questions.filter { $0.section == section }
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(section.displayName) · \(items.count) 题")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(accent)
                    ForEach(items) { q in row(q) }
                }
            }
        }
    }

    private func row(_ q: BankQuestion) -> some View {
        let isOpen = expanded.contains(q.id)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                if isOpen { expanded.remove(q.id) } else { expanded.insert(q.id) }
            } label: {
                HStack(spacing: 8) {
                    Text(q.type)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(accent.opacity(0.12), in: Capsule())
                    Text(q.isFigureQuestion ? "图形推理题" : q.stem)
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(BDColor.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)

            if isOpen { detail(q).padding(.bottom, 10) }
            Divider()
        }
    }

    @ViewBuilder
    private func detail(_ q: BankQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let material = q.material, !material.isEmpty {
                Text(material)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(BDColor.textSecondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(BDColor.panelSecondaryFill))
            }
            if !q.isFigureQuestion {
                Text(q.stem).font(.system(.callout, design: .rounded, weight: .medium)).foregroundStyle(BDColor.textPrimary)
            }
            if let prompt = q.figurePrompt {
                HStack(spacing: 8) {
                    ForEach(Array(prompt.enumerated()), id: \.offset) { _, spec in
                        FigureView(spec: spec, size: 40, color: BDColor.textPrimary)
                            .frame(width: 56, height: 56)
                            .background(RoundedRectangle(cornerRadius: 10).fill(BDColor.panelSecondaryFill))
                    }
                    Text("?").font(.system(.title2, weight: .bold)).foregroundStyle(accent)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(q.options.enumerated()), id: \.offset) { i, opt in
                    let correct = i == q.answerIndex
                    HStack(spacing: 8) {
                        Text(String(UnicodeScalar(65 + i)!))
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(correct ? BDColor.green : BDColor.textSecondary)
                            .frame(width: 18)
                        if let figs = q.figureOptions, figs.indices.contains(i) {
                            FigureView(spec: figs[i], size: 34, color: correct ? BDColor.green : BDColor.textPrimary)
                                .frame(width: 48, height: 48)
                                .background(RoundedRectangle(cornerRadius: 8).fill(correct ? BDColor.green.opacity(0.1) : BDColor.panelSecondaryFill))
                        } else {
                            Text(opt).font(.system(.callout, design: .rounded))
                                .foregroundStyle(correct ? BDColor.green : BDColor.textPrimary)
                        }
                        if correct { Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(BDColor.green) }
                    }
                }
            }
            Text("解析：\(q.explanation)")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(BDColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
