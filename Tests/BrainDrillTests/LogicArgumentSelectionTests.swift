import Foundation
import Testing
@testable import BrainDrill

struct LogicArgumentSelectionTests {
    /// `nextPassage(difficulty:recentIDs:)` must show every passage of a given
    /// difficulty before repeating any — i.e. the first `poolSize` picks are all
    /// distinct, cycling through the whole pool.
    @Test func cyclesThroughWholePoolBeforeRepeating() {
        let difficulty = 1
        let poolIDs = Set(LogicArgumentPassageLibrary.all.filter { $0.difficulty == difficulty }.map(\.id))
        guard !poolIDs.isEmpty else { return }

        var recent: [String] = []
        var picked: [String] = []
        for _ in 0..<poolIDs.count {
            let passage = LogicArgumentPassageLibrary.nextPassage(difficulty: difficulty, recentIDs: recent)
            picked.append(passage.id)
            recent.append(passage.id)
        }

        // No repeats within one full cycle, and the cycle covers the entire pool.
        #expect(Set(picked).count == poolIDs.count)
        #expect(Set(picked) == poolIDs)
    }

    @Test func repeatsOnlyAfterExhaustingPool() {
        let difficulty = 1
        let poolSize = LogicArgumentPassageLibrary.all.filter { $0.difficulty == difficulty }.count
        guard poolSize >= 2 else { return }

        var recent: [String] = []
        for _ in 0..<poolSize {
            let passage = LogicArgumentPassageLibrary.nextPassage(difficulty: difficulty, recentIDs: recent)
            recent.append(passage.id)
        }
        // Pool is now fully seen; the next pick is allowed to repeat, but it must
        // be the least-recently-seen one (the oldest), not an arbitrary recent one.
        let next = LogicArgumentPassageLibrary.nextPassage(difficulty: difficulty, recentIDs: recent)
        #expect(next.id == recent.first)
    }
}
