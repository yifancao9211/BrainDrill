import SwiftUI

enum BDColor {
    static let accent = Color("Accent", bundle: nil)

    static let primaryBlue = Color(light: .init(red: 0.17, green: 0.41, blue: 0.72),
                                   dark: .init(red: 0.40, green: 0.62, blue: 0.95))

    static let warm = Color(light: .init(red: 0.51, green: 0.34, blue: 0.12),
                            dark: .init(red: 0.78, green: 0.62, blue: 0.38))

    static let teal = Color(light: .init(red: 0.12, green: 0.48, blue: 0.39),
                            dark: .init(red: 0.30, green: 0.72, blue: 0.60))

    static let green = Color(light: .init(red: 0.16, green: 0.52, blue: 0.42),
                             dark: .init(red: 0.32, green: 0.74, blue: 0.60))

    static let gold = Color(light: .init(red: 0.75, green: 0.56, blue: 0.18),
                            dark: .init(red: 0.90, green: 0.72, blue: 0.32))

    static let error = Color(light: .init(red: 0.72, green: 0.34, blue: 0.25),
                             dark: .init(red: 0.92, green: 0.50, blue: 0.40))

    static let tileCompleted = Color(light: .init(red: 0.82, green: 0.88, blue: 0.84),
                                     dark: .init(red: 0.22, green: 0.30, blue: 0.24))

    static let tileCompletedText = Color(light: .init(red: 0.33, green: 0.42, blue: 0.35),
                                         dark: .init(red: 0.60, green: 0.72, blue: 0.62))

    static let tileDefault = Color(light: .white.opacity(0.78),
                                   dark: .white.opacity(0.10))

    static let cardStroke = Color(light: .white.opacity(0.28),
                                  dark: .white.opacity(0.10))

    static let sidebarSelected = Color(light: .white.opacity(0.72),
                                       dark: .white.opacity(0.12))

    static let historyRow = Color(light: .white.opacity(0.56),
                                  dark: .white.opacity(0.08))

    static let barTrack = Color(light: .black.opacity(0.05),
                                dark: .white.opacity(0.08))

    static let difficultySelected = Color(light: .init(red: 0.17, green: 0.41, blue: 0.72).opacity(0.16),
                                          dark: .init(red: 0.40, green: 0.62, blue: 0.95).opacity(0.20))

    static let difficultyDefault = Color(light: .white.opacity(0.45),
                                         dark: .white.opacity(0.06))

    static let flankerAccent = Color(light: .init(red: 0.52, green: 0.32, blue: 0.75),
                                     dark: .init(red: 0.68, green: 0.50, blue: 0.90))

    static let goNoGoAccent = Color(light: .init(red: 0.85, green: 0.48, blue: 0.20),
                                    dark: .init(red: 0.95, green: 0.60, blue: 0.32))

    static let nBackAccent = Color(light: .init(red: 0.15, green: 0.55, blue: 0.62),
                                   dark: .init(red: 0.28, green: 0.70, blue: 0.78))

    static let digitSpanAccent = Color(light: .init(red: 0.22, green: 0.50, blue: 0.72),
                                       dark: .init(red: 0.42, green: 0.68, blue: 0.92))

    static let choiceRTAccent = Color(light: .init(red: 0.78, green: 0.42, blue: 0.22),
                                      dark: .init(red: 0.92, green: 0.58, blue: 0.35))

    static let changeDetectionAccent = Color(light: .init(red: 0.45, green: 0.55, blue: 0.28),
                                             dark: .init(red: 0.58, green: 0.72, blue: 0.40))

    static let visualSearchAccent = Color(light: .init(red: 0.62, green: 0.28, blue: 0.55),
                                          dark: .init(red: 0.78, green: 0.45, blue: 0.72))

    static let distractionColors: [Color] = [
        Color(light: .init(red: 0.90, green: 0.42, blue: 0.38), dark: .init(red: 0.85, green: 0.40, blue: 0.35)),
        Color(light: .init(red: 0.30, green: 0.65, blue: 0.85), dark: .init(red: 0.35, green: 0.60, blue: 0.80)),
        Color(light: .init(red: 0.92, green: 0.72, blue: 0.22), dark: .init(red: 0.88, green: 0.68, blue: 0.25)),
        Color(light: .init(red: 0.55, green: 0.78, blue: 0.35), dark: .init(red: 0.45, green: 0.70, blue: 0.32)),
        Color(light: .init(red: 0.68, green: 0.45, blue: 0.82), dark: .init(red: 0.62, green: 0.42, blue: 0.78)),
        Color(light: .init(red: 0.95, green: 0.55, blue: 0.30), dark: .init(red: 0.90, green: 0.50, blue: 0.28)),
    ]
}

enum BDGradient {
    static let primaryBlue = LinearGradient(
        colors: [BDColor.primaryBlue, BDColor.primaryBlue.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sidebarLight = LinearGradient(
        colors: [Color(red: 0.95, green: 0.93, blue: 0.89), Color(red: 0.88, green: 0.90, blue: 0.94)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let sidebarDark = LinearGradient(
        colors: [Color(red: 0.10, green: 0.10, blue: 0.12), Color(red: 0.12, green: 0.13, blue: 0.16)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let detailLight = LinearGradient(
        colors: [Color(red: 0.98, green: 0.97, blue: 0.94), Color(red: 0.91, green: 0.94, blue: 0.97)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let detailDark = LinearGradient(
        colors: [Color(red: 0.08, green: 0.08, blue: 0.10), Color(red: 0.11, green: 0.12, blue: 0.15)],
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
