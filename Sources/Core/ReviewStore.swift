import Foundation

/// 一道错题的复习状态（间隔重复 / SM-2 简化版）。
struct ReviewItem: Codable, Equatable {
    var ease: Double = 2.3        // 难度系数（越小越频繁）
    var intervalDays: Double = 0  // 当前复习间隔（天）
    var dueAt: Date               // 下次到期时间
    var lapses: Int = 0           // 累计答错次数
}

/// 错题本 + 间隔重复调度。逻辑推理与考公共用同一题库 id 空间，故为全局存储（UserDefaults）。
enum ReviewStore {
    private static let key = "qbank_review_v1"
    static let graduateIntervalDays = 21.0   // 间隔达到此值即「毕业」移出错题本

    static func load() -> [String: ReviewItem] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let map = try? JSONDecoder().decode([String: ReviewItem].self, from: data) else { return [:] }
        return map
    }

    static func save(_ map: [String: ReviewItem]) {
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// 到期（应复习）的题 id。
    static func dueIDs(now: Date = Date()) -> Set<String> {
        Set(load().filter { $0.value.dueAt <= now }.keys)
    }

    static func dueCount(now: Date = Date()) -> Int { dueIDs(now: now).count }

    /// 记录一次会话作答：
    /// - 答错 → 进/留错题本，立即到期、降低 ease；
    /// - 答对且在错题本中 → 按 SM-2 拉长间隔、升高 ease，间隔达标则毕业移除；
    /// - 答对但不在错题本 → 忽略。
    static func record(_ answers: [(id: String, correct: Bool)], now: Date = Date()) {
        var map = load()
        for answer in answers {
            if answer.correct {
                guard var item = map[answer.id] else { continue }
                item.intervalDays = item.intervalDays <= 0 ? 1 : item.intervalDays * item.ease
                item.ease = min(item.ease + 0.1, 3.0)
                item.dueAt = now.addingTimeInterval(item.intervalDays * 86_400)
                if item.intervalDays >= graduateIntervalDays {
                    map[answer.id] = nil          // 毕业
                } else {
                    map[answer.id] = item
                }
            } else {
                var item = map[answer.id] ?? ReviewItem(dueAt: now)
                item.lapses += 1
                item.ease = max(item.ease - 0.2, 1.3)
                item.intervalDays = 0
                item.dueAt = now                  // 立即到期，优先复习
                map[answer.id] = item
            }
        }
        save(map)
    }
}
