import SwiftUI

enum BDColor {
    static let accent = Color("Accent", bundle: nil)

    static let appBackground = Color(
        light: .init(red: 0.949, green: 0.957, blue: 0.965),
        dark: .init(red: 0.110, green: 0.110, blue: 0.118)
    )

    static let sidebarBackground = Color.clear

    static let contentBackground = Color(
        light: .init(red: 0.957, green: 0.971, blue: 0.985),
        dark: .init(red: 0.064, green: 0.077, blue: 0.098)
    )

    static let panelFill = Color(
        light: .white.opacity(0.72),
        dark: .white.opacity(0.045)
    )

    static let panelSecondaryFill = Color(
        light: .black.opacity(0.028),
        dark: .white.opacity(0.035)
    )

    static let stageFill = Color(
        light: .white.opacity(0.94),
        dark: .white.opacity(0.070)
    )

    static let overlayFill = Color(
        light: .white.opacity(0.95),
        dark: .init(red: 0.118, green: 0.137, blue: 0.171).opacity(0.95)
    )

    static let borderSubtle = Color(
        light: .init(red: 0.126, green: 0.176, blue: 0.247).opacity(0.10),
        dark: .white.opacity(0.10)
    )

    static let borderStrong = Color(
        light: .init(red: 0.126, green: 0.176, blue: 0.247).opacity(0.18),
        dark: .white.opacity(0.18)
    )

    static let textPrimary = Color(
        light: .init(red: 0.102, green: 0.141, blue: 0.192),
        dark: .init(red: 0.930, green: 0.950, blue: 0.976)
    )

    static let textSecondary = Color(
        light: .init(red: 0.324, green: 0.392, blue: 0.482),
        dark: .init(red: 0.650, green: 0.708, blue: 0.787)
    )

    static let textTertiary = Color(
        light: .init(red: 0.470, green: 0.541, blue: 0.620),
        dark: .init(red: 0.470, green: 0.541, blue: 0.620)
    )

    static let primaryBlue = Color(
        light: .init(red: 0.114, green: 0.380, blue: 0.686),
        dark: .init(red: 0.384, green: 0.620, blue: 0.922)
    )

    static let teal = Color(
        light: .init(red: 0.102, green: 0.487, blue: 0.553),
        dark: .init(red: 0.345, green: 0.716, blue: 0.788)
    )

    static let green = Color(
        light: .init(red: 0.178, green: 0.533, blue: 0.404),
        dark: .init(red: 0.396, green: 0.778, blue: 0.617)
    )

    static let warm = Color(
        light: .init(red: 0.667, green: 0.427, blue: 0.184),
        dark: .init(red: 0.865, green: 0.653, blue: 0.384)
    )

    static let gold = Color(
        light: .init(red: 0.773, green: 0.583, blue: 0.192),
        dark: .init(red: 0.922, green: 0.768, blue: 0.349)
    )

    static let error = Color(
        light: .init(red: 0.720, green: 0.286, blue: 0.267),
        dark: .init(red: 0.938, green: 0.463, blue: 0.427)
    )

    static let tileCompleted = Color(
        light: .init(red: 0.830, green: 0.896, blue: 0.878),
        dark: .init(red: 0.187, green: 0.274, blue: 0.249)
    )

    static let tileCompletedText = Color(
        light: .init(red: 0.239, green: 0.373, blue: 0.318),
        dark: .init(red: 0.620, green: 0.765, blue: 0.702)
    )

    static let tileDefault = Color(
        light: .white.opacity(0.92),
        dark: .white.opacity(0.085)
    )

    static let cardStroke = Color(
        light: .white.opacity(0.52),
        dark: .white.opacity(0.12)
    )

    static let sidebarSelected = Color(
        light: .white.opacity(0.92),
        dark: .white.opacity(0.10)
    )

    static let sidebarHover = Color(
        light: .black.opacity(0.035),
        dark: .white.opacity(0.050)
    )

    static let cardHover = Color(
        light: .init(red: 0.097, green: 0.171, blue: 0.276).opacity(0.055),
        dark: .white.opacity(0.065)
    )

    static let rowHover = Color(
        light: .init(red: 0.097, green: 0.171, blue: 0.276).opacity(0.045),
        dark: .white.opacity(0.055)
    )

    static let rowSelected = Color(
        light: primaryBlue.opacity(0.10),
        dark: primaryBlue.opacity(0.16)
    )

    static let focusRing = Color(
        light: primaryBlue.opacity(0.34),
        dark: primaryBlue.opacity(0.48)
    )

    static let focusRingStrong = Color(
        light: primaryBlue.opacity(0.52),
        dark: primaryBlue.opacity(0.68)
    )

    static let pressedOverlay = Color(
        light: .black.opacity(0.045),
        dark: .white.opacity(0.06)
    )

    static let historyRow = Color(
        light: .white.opacity(0.72),
        dark: .white.opacity(0.075)
    )

    static let inputFill = Color(
        light: .white.opacity(0.82),
        dark: .white.opacity(0.085)
    )

    static let tableHeaderFill = Color(
        light: .init(red: 0.938, green: 0.954, blue: 0.976),
        dark: .white.opacity(0.050)
    )

    static let barTrack = Color(
        light: .black.opacity(0.06),
        dark: .white.opacity(0.09)
    )

    static let difficultySelected = Color(
        light: primaryBlue.opacity(0.12),
        dark: primaryBlue.opacity(0.22)
    )

    static let difficultyDefault = Color(
        light: .white.opacity(0.56),
        dark: .white.opacity(0.06)
    )

    static let flankerAccent = Color(
        light: .init(red: 0.447, green: 0.364, blue: 0.757),
        dark: .init(red: 0.655, green: 0.573, blue: 0.906)
    )

    static let goNoGoAccent = Color(
        light: .init(red: 0.773, green: 0.443, blue: 0.216),
        dark: .init(red: 0.922, green: 0.620, blue: 0.369)
    )

    static let nBackAccent = Color(
        light: .init(red: 0.118, green: 0.517, blue: 0.604),
        dark: .init(red: 0.353, green: 0.727, blue: 0.808)
    )

    static let digitSpanAccent = Color(
        light: .init(red: 0.176, green: 0.454, blue: 0.722),
        dark: .init(red: 0.427, green: 0.663, blue: 0.941)
    )

    static let choiceRTAccent = Color(
        light: .init(red: 0.686, green: 0.424, blue: 0.224),
        dark: .init(red: 0.875, green: 0.600, blue: 0.392)
    )

    static let changeDetectionAccent = Color(
        light: .init(red: 0.373, green: 0.561, blue: 0.318),
        dark: .init(red: 0.549, green: 0.741, blue: 0.467)
    )

    static let visualSearchAccent = Color(
        light: .init(red: 0.514, green: 0.329, blue: 0.667),
        dark: .init(red: 0.729, green: 0.522, blue: 0.867)
    )

    static let corsiBlockAccent = Color(
        light: .init(red: 0.137, green: 0.474, blue: 0.655),
        dark: .init(red: 0.369, green: 0.694, blue: 0.859)
    )

    static let stopSignalAccent = Color(
        light: .init(red: 0.710, green: 0.286, blue: 0.302),
        dark: .init(red: 0.898, green: 0.447, blue: 0.471)
    )

    static let syllogismAccent = Color(
        light: .init(red: 0.353, green: 0.365, blue: 0.769),
        dark: .init(red: 0.580, green: 0.596, blue: 0.918)
    )

    static let logicArgumentAccent = Color(
        light: .init(red: 0.443, green: 0.345, blue: 0.710),
        dark: .init(red: 0.659, green: 0.541, blue: 0.863)
    )

    static let distractionColors: [Color] = [
        Color(light: .init(red: 0.820, green: 0.396, blue: 0.380), dark: .init(red: 0.875, green: 0.420, blue: 0.392)),
        Color(light: .init(red: 0.247, green: 0.604, blue: 0.808), dark: .init(red: 0.329, green: 0.655, blue: 0.855)),
        Color(light: .init(red: 0.820, green: 0.655, blue: 0.247), dark: .init(red: 0.890, green: 0.733, blue: 0.310)),
        Color(light: .init(red: 0.427, green: 0.702, blue: 0.412), dark: .init(red: 0.494, green: 0.757, blue: 0.451)),
        Color(light: .init(red: 0.600, green: 0.447, blue: 0.776), dark: .init(red: 0.706, green: 0.553, blue: 0.878)),
        Color(light: .init(red: 0.875, green: 0.561, blue: 0.318), dark: .init(red: 0.925, green: 0.631, blue: 0.388))
    ]
}

enum BDGradient {
    static let appChrome = LinearGradient(
        colors: [BDColor.sidebarBackground, BDColor.appBackground],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let detailLight = LinearGradient(
        colors: [BDColor.contentBackground, BDColor.appBackground],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let detailDark = LinearGradient(
        colors: [BDColor.contentBackground, BDColor.appBackground],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sidebarLight = LinearGradient(
        colors: [BDColor.sidebarBackground, BDColor.contentBackground.opacity(0.92)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let sidebarDark = LinearGradient(
        colors: [BDColor.sidebarBackground, BDColor.contentBackground.opacity(0.92)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let primaryBlue = LinearGradient(
        colors: [BDColor.primaryBlue, BDColor.teal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        })
    }
}

enum BDMetrics {
    static let controlHeightCompact: CGFloat = 40
    static let controlHeightRegular: CGFloat = 44
    static let sidebarWidthDefault: CGFloat = 220
    static let sidebarWidthExpanded: CGFloat = 260
    static let contentMaxReadableWidth: CGFloat = 860
    static let contentMaxWorkbenchWidth: CGFloat = 1180
    static let contentMaxAnalysisWidth: CGFloat = 1260
    static let contentMaxTrainingWidth: CGFloat = 1120
    static let spacingCompact: CGFloat = 16
    static let spacingRegular: CGFloat = 20
    static let cornerRadiusSmall: CGFloat = 6
    static let cornerRadiusMedium: CGFloat = 10
    static let cornerRadiusLarge: CGFloat = 12
}
