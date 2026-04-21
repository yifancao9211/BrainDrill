import SwiftUI

struct ReadingModuleIntroCard: View {
    let title: String
    let subtitle: String
    let stats: [(String, String, Color)]
    let accent: Color
    let actionTitle: String
    let action: () -> Void
    @FocusState private var isPrimaryActionFocused: Bool

    var body: some View {
        SurfaceCard(title: title, subtitle: subtitle) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: min(stats.count, 3)), spacing: 12) {
                ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                    MetricTile(label: stat.0, value: stat.1, accent: stat.2)
                }
            }

            Button(action: action) {
                Text(actionTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(BDPrimaryButton(accent: accent))
            .keyboardShortcut(.defaultAction)
            .focused($isPrimaryActionFocused)
            .bdFocusRing(cornerRadius: 14)
            .onAppear {
                isPrimaryActionFocused = true
            }
        }
    }
}

struct PassageStage: View {
    let passage: ReadingPassage
    let accent: Color
    let footer: AnyView

    init<Footer: View>(passage: ReadingPassage, accent: Color, @ViewBuilder footer: () -> Footer) {
        self.passage = passage
        self.accent = accent
        self.footer = AnyView(footer())
    }

    var body: some View {
        BDTrainingStage(accent: accent) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(passage.title)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(BDColor.textPrimary)
                        HStack(spacing: 8) {
                            InfoPill(title: passage.domainTag, accent: accent)
                            InfoPill(title: "难度 \(passage.difficulty)", accent: BDColor.textSecondary)
                            InfoPill(title: passage.structureType.label, accent: BDColor.warm)
                        }
                    }
                    Spacer()
                }

                ScrollView {
                    Text(passage.body)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(BDColor.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(BDColor.panelSecondaryFill.opacity(0.35))
                        )
                }
                .frame(minHeight: 260, maxHeight: 360)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(BDColor.borderSubtle, lineWidth: 1)
                )

                footer
            }
        }
    }
}

struct ReadingPromptEditor: View {
    let title: String
    let subtitle: String
    let placeholder: String
    @Binding var text: String
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(BDColor.textPrimary)
            Text(subtitle)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(BDColor.textSecondary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(BDColor.panelSecondaryFill.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(BDColor.borderSubtle, lineWidth: 1)
                    )

                TextEditor(text: $text)
                    .font(.system(.body, design: .rounded))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .focused($isEditorFocused)
                    .accessibilityLabel(title)
                    .accessibilityHint(subtitle)

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(BDColor.textSecondary.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 120)
            .bdFocusRing(cornerRadius: 16)
        }
    }
}

struct ReadingChipButton: View {
    let title: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        BDSelectionChip(title: title, isSelected: isSelected, accent: accent, action: action)
    }
}

struct ReadingOptionButton: View {
    let title: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        BDSelectionOptionCard(isSelected: isSelected, accent: accent, action: action) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(isSelected ? accent : accent.opacity(0.18))
                    .frame(width: 10, height: 10)
                    .padding(.top, 6)

                Text(title)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(BDColor.textPrimary)

                Spacer()
            }
        }
    }
}
