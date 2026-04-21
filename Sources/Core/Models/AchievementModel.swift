import Foundation

/// Achievement definitions and tracker for motivational feedback.
struct Achievement: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let icon: String
    var unlockedAt: Date?

    var isUnlocked: Bool { unlockedAt != nil }

    static let allDefinitions: [Achievement] = [
        Achievement(id: "first-session", title: "初次启程", description: "完成第一次训练", icon: "star.fill"),
        Achievement(id: "streak-3", title: "三日连胜", description: "连续训练 3 天", icon: "flame"),
        Achievement(id: "streak-7", title: "周周不落", description: "连续训练 7 天", icon: "flame.fill"),
        Achievement(id: "streak-30", title: "月度坚持", description: "连续训练 30 天", icon: "trophy.fill"),
        Achievement(id: "all-modules", title: "全面发展", description: "每个活跃模块至少训练一次", icon: "brain.head.profile"),
        Achievement(id: "reading-10", title: "阅读新手", description: "完成 10 次阅读训练", icon: "book.fill"),
        Achievement(id: "reading-50", title: "阅读达人", description: "完成 50 次阅读训练", icon: "books.vertical.fill"),
        Achievement(id: "schulte-master", title: "方格大师", description: "舒尔特方格达到 7×7 难度", icon: "square.grid.3x3.fill"),
        Achievement(id: "accuracy-90", title: "精准判断", description: "任意阅读模块连续 5 次正确率 ≥ 90%", icon: "target"),
        Achievement(id: "cognitive-balanced", title: "均衡认知", description: "认知画像各维度均 ≥ 60 分", icon: "chart.pie.fill"),
    ]
}

struct AchievementTracker: Codable, Equatable {
    var achievements: [Achievement]

    init(achievements: [Achievement]? = nil) {
        self.achievements = achievements ?? Achievement.allDefinitions
    }

    var unlockedCount: Int {
        achievements.filter(\.isUnlocked).count
    }

    var recentlyUnlocked: [Achievement] {
        achievements
            .filter(\.isUnlocked)
            .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
    }

    mutating func evaluate(
        sessions: [SessionResult],
        streak: StreakTracker,
        cognitiveProfile: CognitiveProfile
    ) -> [Achievement] {
        var newlyUnlocked: [Achievement] = []
        let now = Date()

        func unlock(_ id: String) {
            guard let index = achievements.firstIndex(where: { $0.id == id && !$0.isUnlocked }) else { return }
            achievements[index].unlockedAt = now
            newlyUnlocked.append(achievements[index])
        }

        // First session
        if !sessions.isEmpty {
            unlock("first-session")
        }

        // Streak milestones
        if streak.currentStreak >= 3 { unlock("streak-3") }
        if streak.currentStreak >= 7 { unlock("streak-7") }
        if streak.currentStreak >= 30 { unlock("streak-30") }

        // All modules
        let activeModules: Set<TrainingModule> = [.mainIdea, .evidenceMap, .delayedRecall, .schulte, .visualSearch, .nBack]
        let trainedModules = Set(sessions.map(\.module))
        if activeModules.isSubset(of: trainedModules) {
            unlock("all-modules")
        }

        // Reading counts
        let readingCount = sessions.filter { [.mainIdea, .evidenceMap, .delayedRecall].contains($0.module) }.count
        if readingCount >= 10 { unlock("reading-10") }
        if readingCount >= 50 { unlock("reading-50") }

        // Schulte difficulty
        let schulteSessions = sessions.compactMap { session -> SchulteMetrics? in
            if case let .schulte(m) = session.metrics { return m } else { return nil }
        }
        if schulteSessions.contains(where: { $0.difficulty == .master7x7 || $0.difficulty == .elite8x8 || $0.difficulty == .legend9x9 }) {
            unlock("schulte-master")
        }

        // Cognitive balance - check dimension by ID
        func dimScore(_ id: String) -> Double {
            cognitiveProfile.dimensions.first(where: { $0.id == id })?.score ?? 0
        }
        let scores = ["memoryCapacity", "reactionSpeed", "inhibitionControl", "visualSearch", "visualWorkingMemory"]
            .map { dimScore($0) }
        if !scores.isEmpty && scores.allSatisfy({ $0 >= 60 }) {
            unlock("cognitive-balanced")
        }

        return newlyUnlocked
    }
}
