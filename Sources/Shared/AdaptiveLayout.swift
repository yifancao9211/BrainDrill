import SwiftUI

// MARK: - Adaptive Side-by-Side Layout

/// Lays out two views side by side on wide screens (macOS / iPad landscape)
/// and vertically on narrow screens (iPhone portrait).
struct BDAdaptiveColumns<Primary: View, Secondary: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    let secondaryWidth: CGFloat
    @ViewBuilder var primary: Primary
    @ViewBuilder var secondary: Secondary

    init(secondaryWidth: CGFloat = 320, @ViewBuilder primary: () -> Primary, @ViewBuilder secondary: () -> Secondary) {
        self.secondaryWidth = secondaryWidth
        self.primary = primary()
        self.secondary = secondary()
    }

    var body: some View {
        #if os(iOS)
        VStack(spacing: 20) {
            primary
            secondary
        }
        #else
        HStack(alignment: .top, spacing: 20) {
            primary.frame(maxWidth: .infinity)
            secondary.frame(width: secondaryWidth)
        }
        #endif
    }
}

// MARK: - Adaptive Stat Row

/// Displays stat cards in a 2×2 grid on iPhone, horizontal row on macOS.
struct BDAdaptiveStatRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        #if os(iOS)
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            content
        }
        #else
        HStack(spacing: 14) {
            content
        }
        #endif
    }
}

// MARK: - Cross-platform Table Replacement

/// On iOS, renders rows as a simple List since multi-column Table is macOS-only.
/// On macOS, this is not used — callers should use `#if os(iOS)` to branch.

// MARK: - Hover helper

extension View {
    /// Applies `.onHover` only on macOS; no-op on iOS (avoids lint warnings).
    func bdOnHover(_ action: @escaping (Bool) -> Void) -> some View {
        #if os(macOS)
        self.onHover(perform: action)
        #else
        self
        #endif
    }
}
