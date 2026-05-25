import SwiftUI

/// 素材详情 Sheet —— 展示完整的 ReadingPassage 内容，跨平台通用。
struct PassageDetailSheet: View {
    let passage: ReadingPassage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            InfoPill(title: passage.domainTag, accent: BDColor.teal)
                            InfoPill(title: "难度 \(passage.difficulty)", accent: difficultyColor)
                            InfoPill(title: passage.structureType.label, accent: BDColor.warm)
                        }

                        Text("\(passage.body.count) 字")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(BDColor.textSecondary)
                    }

                    Divider()

                    // Body text
                    sectionHeader("正文", icon: "doc.text.fill")
                    Text(passage.body)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(BDColor.textPrimary)
                        .textSelection(.enabled)
                        .lineSpacing(6)

                    Divider()

                    // Main Idea
                    sectionHeader("主旨理解", icon: "lightbulb.fill")
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(passage.mainIdeaOptions.enumerated()), id: \.offset) { index, option in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: index == passage.mainIdeaAnswerIndex ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(index == passage.mainIdeaAnswerIndex ? .green : BDColor.textSecondary)
                                    .font(.system(.body, weight: .semibold))

                                Text(option)
                                    .font(.system(.callout, design: .rounded))
                                    .foregroundStyle(index == passage.mainIdeaAnswerIndex ? BDColor.textPrimary : BDColor.textSecondary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(index == passage.mainIdeaAnswerIndex
                                        ? Color.green.opacity(0.08)
                                        : BDColor.panelSecondaryFill)
                            )
                        }
                    }

                    // Rubric
                    if !passage.mainIdeaRubric.idealSummary.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("理想摘要")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(BDColor.teal)
                            Text(passage.mainIdeaRubric.idealSummary)
                                .font(.system(.callout, design: .rounded))
                                .foregroundStyle(BDColor.textSecondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(BDColor.teal.opacity(0.06)))
                    }

                    Divider()

                    // Claims
                    sectionHeader("结论锚点 (\(passage.claimAnchors.count))", icon: "pin.fill")
                    ForEach(passage.claimAnchors) { claim in
                        HStack(alignment: .top, spacing: 10) {
                            InfoPill(title: claim.scope.label, accent: claim.scope == .global ? BDColor.gold : BDColor.primaryBlue)
                            Text(claim.text)
                                .font(.system(.callout, design: .rounded))
                                .foregroundStyle(BDColor.textPrimary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(BDColor.panelSecondaryFill))
                    }

                    Divider()

                    // Evidence
                    sectionHeader("证据分类 (\(passage.evidenceItems.count))", icon: "list.bullet.clipboard.fill")
                    ForEach(passage.evidenceItems) { item in
                        HStack(alignment: .top, spacing: 10) {
                            InfoPill(title: item.role.label, accent: roleColor(item.role))
                            Text(item.text)
                                .font(.system(.callout, design: .rounded))
                                .foregroundStyle(BDColor.textPrimary)
                                .lineLimit(3)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(BDColor.panelSecondaryFill))
                    }

                    Divider()

                    // Recall
                    sectionHeader("延迟回忆 (\(passage.recallPrompts.count) 项)", icon: "brain.head.profile")

                    Text("关键词: \(passage.recallKeywords.joined(separator: "、"))")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(BDColor.textSecondary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(BDColor.panelSecondaryFill))

                    ForEach(passage.recallPrompts) { prompt in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: prompt.isTarget ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(prompt.isTarget ? .green : BDColor.textSecondary)
                            Text(prompt.text)
                                .font(.system(.callout, design: .rounded))
                                .foregroundStyle(BDColor.textPrimary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(
                            prompt.isTarget ? Color.green.opacity(0.06) : BDColor.panelSecondaryFill))
                    }

                    if let references = passage.references, !references.isEmpty {
                        Divider()

                        sectionHeader("参考资料 (\(references.count))", icon: "books.vertical.fill")
                        ForEach(references) { reference in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(reference.title)
                                    .font(.system(.callout, design: .rounded, weight: .semibold))
                                    .foregroundStyle(BDColor.textPrimary)

                                Text(referenceLine(reference))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(BDColor.textSecondary)
                                    .textSelection(.enabled)

                                if let notes = reference.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(BDColor.textSecondary)
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 10).fill(BDColor.panelSecondaryFill))
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 800)
            }
            .navigationTitle(passage.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 700, idealWidth: 800, minHeight: 600, idealHeight: 750)
        #endif
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(BDColor.primaryBlue)
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(BDColor.textPrimary)
        }
    }

    private var difficultyColor: Color {
        switch passage.difficulty {
        case 1: BDColor.green
        case 2: BDColor.warm
        default: BDColor.error
        }
    }

    private func roleColor(_ role: EvidenceClassificationItem.Role) -> Color {
        switch role {
        case .claim: BDColor.gold
        case .evidence: BDColor.green
        case .background: BDColor.primaryBlue
        case .limitation: BDColor.error
        }
    }

    private func referenceLine(_ reference: MaterialReference) -> String {
        var parts: [String] = []
        if !reference.authors.isEmpty {
            parts.append(reference.authors.joined(separator: ", "))
        }
        parts.append("\(reference.year)")
        parts.append(reference.source)
        if let doi = reference.doi, !doi.isEmpty {
            parts.append("DOI: \(doi)")
        }
        if let url = reference.url, !url.isEmpty {
            parts.append(url)
        }
        return parts.joined(separator: " · ")
    }
}

// Make ReadingPassage usable with .sheet(item:)
extension ReadingPassage: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
