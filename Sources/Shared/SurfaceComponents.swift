import SwiftUI

enum BDSurfaceTone {
    case primary
    case secondary
    case stage
    case overlay
}

private struct BDPanelSurfaceModifier: ViewModifier {
    let tone: BDSurfaceTone
    let cornerRadius: CGFloat

    private var fillColor: Color {
        switch tone {
        case .primary:
            BDColor.panelFill
        case .secondary:
            BDColor.panelSecondaryFill
        case .stage:
            BDColor.stageFill
        case .overlay:
            BDColor.overlayFill
        }
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background(fillColor, in: shape)
            .overlay(shape.stroke(BDColor.borderSubtle, lineWidth: 0.8))
            .modifier(BDGlassEffectModifier(cornerRadius: cornerRadius))
    }
}

private struct BDGlassEffectModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
        }
    }
}

extension View {
    func bdPanelSurface(_ tone: BDSurfaceTone = .primary, cornerRadius: CGFloat = 20) -> some View {
        modifier(BDPanelSurfaceModifier(tone: tone, cornerRadius: cornerRadius))
    }
}

struct SurfaceCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(BDColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(BDColor.textSecondary)
                }
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bdPanelSurface(.primary, cornerRadius: 22)
    }
}

struct MetricTile: View {
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(BDColor.textSecondary)
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(0.12), lineWidth: 0.8)
        )
    }
}

struct InfoPill: View {
    let title: String
    let accent: Color

    var body: some View {
        Text(title)
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.10))
            )
            .foregroundStyle(accent)
    }
}

struct BDWorkbenchPage<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(BDColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(BDColor.textSecondary)
                }
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BDTrainingStage<Content: View>: View {
    let accent: Color
    @ViewBuilder var content: Content

    init(accent: Color, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack {
            content
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .bdPanelSurface(.stage, cornerRadius: 28)
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(accent.opacity(0.9))
                .frame(width: 64, height: 3)
                .clipShape(Capsule())
                .padding(.top, 10)
                .padding(.leading, 14)
        }
    }
}

struct BDResultPanel<Content: View>: View {
    let title: String
    let accent: Color
    @ViewBuilder var content: Content

    init(title: String, accent: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 18) {
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(BDColor.textPrimary)

            content
        }
        .padding(22)
        .frame(maxWidth: 460)
        .bdPanelSurface(.overlay, cornerRadius: 26)
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(accent.opacity(0.12), lineWidth: 1)
        )
    }
}

struct BDFeedbackNote: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(BDColor.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .bdPanelSurface(.secondary, cornerRadius: 14)
    }
}
