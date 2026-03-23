import SwiftUI

struct ReadingModuleIntroCard: View {
    let title: String
    let subtitle: String
    let stats: [(String, String, Color)]
    let accent: Color
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        SurfaceCard(title: title, subtitle: subtitle) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: min(stats.count, 3)), spacing: 12) {
                ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                    MetricTile(label: stat.0, value: stat.1, accent: stat.2)
                }
            }

            Button(action: action) {
                Text(actionTitle)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(accent)
                    )
            }
            .buttonStyle(.plain)
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

                TextEditor(text: $text)
                    .font(.system(.body, design: .rounded))
                    .scrollContentBackground(.hidden)
                    .padding(10)

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
        }
    }
}

struct ReadingChipButton: View {
    let title: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(isSelected ? .white : BDColor.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? accent : BDColor.panelSecondaryFill.opacity(0.28))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isSelected ? accent : BDColor.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct ReadingOptionButton: View {
    let title: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.12) : BDColor.panelSecondaryFill.opacity(0.25))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? accent.opacity(0.35) : BDColor.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
