import Foundation

/// Tracks consecutive training days for motivation/streak display.
struct StreakTracker: Codable, Equatable {
    var currentStreak: Int
    var longestStreak: Int
    var lastTrainingDate: Date?

    init(currentStreak: Int = 0, longestStreak: Int = 0, lastTrainingDate: Date? = nil) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastTrainingDate = lastTrainingDate
    }

    mutating func recordTrainingDay(on date: Date = Date()) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        guard let lastDate = lastTrainingDate else {
            currentStreak = 1
            longestStreak = max(longestStreak, 1)
            lastTrainingDate = today
            return
        }

        let lastDay = calendar.startOfDay(for: lastDate)

        if calendar.isDate(today, inSameDayAs: lastDay) {
            // Same day, no change
            return
        }

        let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

        if daysBetween == 1 {
            currentStreak += 1
        } else {
            currentStreak = 1
        }

        longestStreak = max(longestStreak, currentStreak)
        lastTrainingDate = today
    }

    var streakLabel: String {
        if currentStreak >= 7 {
            return "连续 \(currentStreak) 天 🔥"
        }
        if currentStreak >= 3 {
            return "连续 \(currentStreak) 天 ⚡️"
        }
        if currentStreak >= 1 {
            return "连续 \(currentStreak) 天"
        }
        return "今天开始训练吧"
    }
}
