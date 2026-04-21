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
            return BDColor.panelFill
        case .secondary:
            return BDColor.panelSecondaryFill
        case .stage:
            return BDColor.stageFill
        case .overlay:
            return BDColor.overlayFill
        }
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background(fillColor, in: shape)
            .overlay(shape.stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5))
            .modifier(BDGlassEffectModifier(cornerRadius: cornerRadius))
    }
}

private struct BDGlassEffectModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
        }
    }
}

extension View {
    func bdPanelSurface(_ tone: BDSurfaceTone = .primary, cornerRadius: CGFloat = BDMetrics.cornerRadiusLarge) -> some View {
        modifier(BDPanelSurfaceModifier(tone: tone, cornerRadius: cornerRadius))
    }
}

struct BDSectionHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?

    init(eyebrow: String? = nil, title: String, subtitle: String? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(BDColor.textTertiary)
                    .tracking(1.2)
            }

            Text(title)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(BDColor.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(.system(.body, weight: .regular))
                    .foregroundStyle(BDColor.textSecondary)
            }
        }
    }
}

struct SurfaceCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let accent: Color?
    @ViewBuilder var content: Content

    init(title: String, subtitle: String? = nil, accent: Color? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(BDColor.textPrimary)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(.footnote))
                            .foregroundStyle(BDColor.textSecondary)
                    }
                }
                Spacer()
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bdPanelSurface(.primary, cornerRadius: BDMetrics.cornerRadiusLarge)
    }
}

struct BDStatCard: View {
    let label: String
    let value: String
    let note: String?
    let accent: Color
    var icon: String?

    init(label: String, value: String, note: String? = nil, accent: Color, icon: String? = nil) {
        self.label = label
        self.value = value
        self.note = note
        self.accent = accent
        self.icon = icon
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)
                Spacer()
                if let icon {
                    Image(systemName: icon)
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(BDColor.textPrimary)
                .contentTransition(.numericText())

            if let note, !note.isEmpty {
                Text(note)
                    .font(.system(.caption2))
                    .foregroundStyle(BDColor.textTertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: BDMetrics.cornerRadiusMedium, style: .continuous)
                .fill(BDColor.panelSecondaryFill)
        )
    }
}

struct MetricTile: View {
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        BDStatCard(label: label, value: value, accent: accent)
    }
}

struct BDInsightCard: View {
    let title: String
    let bodyText: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(BDColor.textPrimary)
            Text(bodyText)
                .font(.system(.callout))
                .foregroundStyle(BDColor.textSecondary)
                .lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: BDMetrics.cornerRadiusMedium, style: .continuous)
                .fill(BDColor.panelSecondaryFill)
        )
    }
}

struct InfoPill: View {
    let title: String
    let accent: Color

    var body: some View {
        Text(title)
            .font(.system(.caption2, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(accent.opacity(0.10)))
            .foregroundStyle(accent)
    }
}

private struct BDFocusRingModifier: ViewModifier {
    @FocusState private var isFocused: Bool
    let cornerRadius: CGFloat
    let accent: Color

    func body(content: Content) -> some View {
        content
            .focusable()
            .focused($isFocused)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(isFocused ? accent.opacity(0.95) : .clear, lineWidth: isFocused ? 2 : 0)
            )
    }
}

extension View {
    func bdFocusRing(cornerRadius: CGFloat = 16, accent: Color = BDColor.focusRingStrong) -> some View {
        modifier(BDFocusRingModifier(cornerRadius: cornerRadius, accent: accent))
    }

    func bdInputField(cornerRadius: CGFloat = 14) -> some View {
        self
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(minHeight: 42)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(BDColor.inputFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(BDColor.borderSubtle, lineWidth: 1)
            )
            .bdFocusRing(cornerRadius: cornerRadius)
    }
}

struct BDPrimaryButton: ButtonStyle {
    let accent: Color

    init(accent: Color = BDColor.primaryBlue) {
        self.accent = accent
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(configuration.isPressed ? 0.84 : 1.0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BDColor.pressedOverlay.opacity(configuration.isPressed ? 1.0 : 0.0))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct BDSecondaryButton: ButtonStyle {
    let accent: Color

    init(accent: Color = BDColor.primaryBlue) {
        self.accent = accent
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, weight: .semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(configuration.isPressed ? 0.14 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(accent.opacity(0.14), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BDColor.pressedOverlay.opacity(configuration.isPressed ? 0.8 : 0.0))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct BDSidebarSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(BDColor.textTertiary)
                .tracking(1.0)
                .padding(.horizontal, 6)

            VStack(spacing: 6) {
                content
            }
        }
    }
}

struct BDPrimaryNavItem: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let accent: Color
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill((isSelected ? accent : BDColor.textSecondary).opacity(isSelected ? 0.16 : 0.10))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(.callout, weight: .semibold))
                            .foregroundStyle(isSelected ? accent : BDColor.textSecondary)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(BDColor.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(BDColor.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isSelected
                        ? BDColor.sidebarSelected
                        : (isHovering ? BDColor.sidebarHover : .clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? accent.opacity(0.18) : (isHovering ? BDColor.borderSubtle : .clear),
                        lineWidth: 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .bdFocusRing(cornerRadius: 16)
    }
}

struct BDSidebarModuleShortcut: View {
    let title: String
    let count: Int
    let accent: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(.callout, weight: .semibold))
                    .foregroundStyle(BDColor.textPrimary)
                Spacer()
                Text("\(count)")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(accent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isHovering ? BDColor.rowHover : BDColor.panelSecondaryFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isHovering ? accent.opacity(0.18) : BDColor.borderSubtle.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(BDSpringPressStyle())
        .onHover { isHovering = $0 }
        .bdFocusRing(cornerRadius: 14)
    }
}

struct BDFilterBar<Option: Hashable>: View {
    let options: [Option]
    let selection: Option
    let label: (Option) -> String
    let accent: Color
    let onSelect: (Option) -> Void

    var body: some View {
        Picker("", selection: Binding(
            get: { selection },
            set: { onSelect($0) }
        )) {
            ForEach(options, id: \.self) { option in
                Text(label(option)).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

struct BDModuleCard: View {
    let title: String
    let subtitle: String
    let category: String
    let status: String
    let recommendation: String
    let accent: Color
    let icon: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: BDMetrics.cornerRadiusMedium, style: .continuous)
                        .fill(accent.opacity(0.12))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: icon)
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(accent)
                        }

                    Spacer()

                    InfoPill(title: status, accent: accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(BDColor.textPrimary)
                    Text(subtitle)
                        .font(.system(.caption))
                        .foregroundStyle(BDColor.textSecondary)
                        .lineLimit(2)
                }

                Divider()

                HStack {
                    Text(category)
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(BDColor.textSecondary)
                    Spacer()
                    Text(recommendation)
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: BDMetrics.cornerRadiusLarge, style: .continuous)
                    .fill(isHovering ? BDColor.cardHover : BDColor.panelFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BDMetrics.cornerRadiusLarge, style: .continuous)
                    .stroke(isHovering ? accent.opacity(0.18) : Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(BDSpringPressStyle())
        .onHover { isHovering = $0 }
        .bdFocusRing(cornerRadius: BDMetrics.cornerRadiusLarge)
    }
}

struct BDWorkbenchPage<Content: View>: View {
    let title: String
    let subtitle: String?
    let eyebrow: String?
    let maxContentWidth: CGFloat?
    @ViewBuilder var content: Content

    init(title: String, subtitle: String? = nil, eyebrow: String? = nil, maxContentWidth: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.eyebrow = eyebrow
        self.maxContentWidth = maxContentWidth
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.title2, weight: .bold))
                        .foregroundStyle(BDColor.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(.callout))
                            .foregroundStyle(BDColor.textSecondary)
                    }
                }
                content
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: maxContentWidth ?? .infinity, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct BDSettingsRow<Control: View>: View {
    let title: String
    let subtitle: String?
    let controlAlignment: Alignment
    @ViewBuilder var control: Control

    init(
        title: String,
        subtitle: String? = nil,
        controlAlignment: Alignment = .trailing,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.subtitle = subtitle
        self.controlAlignment = controlAlignment
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(BDColor.textPrimary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(.caption))
                        .foregroundStyle(BDColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 16)

            control
                .frame(minWidth: 150, maxWidth: 280, alignment: controlAlignment)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: BDMetrics.cornerRadiusMedium, style: .continuous)
                .fill(BDColor.panelSecondaryFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BDMetrics.cornerRadiusMedium, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5)
        )
    }
}

struct BDTableSection<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(BDColor.textPrimary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(.caption))
                        .foregroundStyle(BDColor.textSecondary)
                }
            }

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(BDColor.panelSecondaryFill.opacity(0.34))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(BDColor.borderSubtle.opacity(0.55), lineWidth: 1)
                )
        }
    }
}

struct BDTrainingShell<Header: View, Stage: View, Footer: View>: View {
    let accent: Color
    @ViewBuilder var header: Header
    @ViewBuilder var stage: Stage
    @ViewBuilder var footer: Footer

    init(accent: Color, @ViewBuilder header: () -> Header, @ViewBuilder stage: () -> Stage, @ViewBuilder footer: () -> Footer) {
        self.accent = accent
        self.header = header()
        self.stage = stage()
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            BDTrainingStage(accent: accent) {
                stage
            }
            footer
        }
        .frame(maxWidth: BDMetrics.contentMaxTrainingWidth, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BDColor.stageFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
        )
    }
}

struct BDResultSummaryCard<Content: View>: View {
    let title: String
    let accent: Color
    @ViewBuilder var content: Content

    init(title: String, accent: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        SurfaceCard(title: title, subtitle: "查看本轮关键指标与下一步建议。", accent: accent) {
            content
        }
    }
}

struct BDResultPanel<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let accent: Color
    @ViewBuilder var content: Content

    @State private var appearAnimation = false

    init(title: String, accent: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [accent.opacity(0.06), Color.clear],
                center: .top,
                startRadius: 10,
                endRadius: appearAnimation ? 400 : 40
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(BDColor.textPrimary)
                    Text("训练已完成")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(accent)
                        .tracking(2)
                }

                content
                    .padding(22)
                    .background(Color.clear.bdPanelSurface(.overlay, cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
                    )
                    .frame(maxWidth: 600)
                    .scaleEffect(appearAnimation ? 1 : 0.97)
                    .opacity(appearAnimation ? 1 : 0)

                Spacer()
            }
        }
        .onAppear {
            if reduceMotion {
                appearAnimation = true
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    appearAnimation = true
                }
            }
        }
    }
}

public struct BDSpringPressStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.interactiveSpring(response: 0.26, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct BDSelectionChip: View {
    let title: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, weight: isSelected ? .semibold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: BDMetrics.controlHeightCompact)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            isSelected
                            ? accent.opacity(0.14)
                            : (isHovering ? BDColor.rowHover : BDColor.panelSecondaryFill)
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            isSelected ? accent.opacity(0.26) : (isHovering ? BDColor.borderSubtle : .clear),
                            lineWidth: 1
                        )
                )
                .foregroundStyle(isSelected ? accent : BDColor.textSecondary)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .bdFocusRing(cornerRadius: 999)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct BDSelectionOptionCard<Content: View>: View {
    let isSelected: Bool
    let accent: Color
    let action: () -> Void
    @ViewBuilder var content: Content

    @State private var isHovering = false

    init(isSelected: Bool, accent: Color, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.accent = accent
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? accent.opacity(0.14) : (isHovering ? BDColor.rowHover : BDColor.panelSecondaryFill))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? accent.opacity(0.30) : (isHovering ? BDColor.borderSubtle : .clear), lineWidth: 1)
                )
        }
        .buttonStyle(BDSpringPressStyle())
        .onHover { isHovering = $0 }
        .bdFocusRing(cornerRadius: 14)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct BDInteractiveRow<Leading: View, Trailing: View>: View {
    let accent: Color
    let isSelected: Bool
    let action: (() -> Void)?
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    @State private var isHovering = false

    init(accent: Color, isSelected: Bool = false, action: (() -> Void)? = nil, @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.accent = accent
        self.isSelected = isSelected
        self.action = action
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) { rowContent }
                    .buttonStyle(BDSpringPressStyle())
                    .bdFocusRing(cornerRadius: 18)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
            } else {
                rowContent
            }
        }
        .onHover { isHovering = $0 }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            leading
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? BDColor.rowSelected : (isHovering ? BDColor.rowHover : BDColor.historyRow))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? accent.opacity(0.22) : (isHovering ? accent.opacity(0.18) : .clear), lineWidth: 1)
        )
    }
}
