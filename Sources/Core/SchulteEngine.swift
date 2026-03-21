import Foundation
import Observation

struct SchulteTile: Identifiable, Hashable {
    let number: Int

    var id: Int { number }
}

enum SchulteTapOutcome {
    case correct(nextNumber: Int)
    case incorrect(expected: Int)
    case completed(SchulteSessionResult)
    case ignored
}

@Observable
final class SchulteEngine {
    let config: SchulteSessionConfig
    let startedAt: Date
    let tiles: [SchulteTile]

    private(set) var nextExpectedNumber: Int = 1
    private(set) var completedNumbers: Set<Int> = []
    private(set) var mistakeCount: Int = 0

    init(
        config: SchulteSessionConfig,
        startedAt: Date = Date(),
        tiles: [SchulteTile]? = nil
    ) {
        self.config = config
        self.startedAt = startedAt
        self.tiles = tiles ?? (1...config.difficulty.totalTiles).shuffled().map { SchulteTile(number: $0) }
    }

    var totalTiles: Int {
        config.difficulty.totalTiles
    }

    var completionFraction: Double {
        Double(completedNumbers.count) / Double(totalTiles)
    }

    func elapsedDuration(at date: Date) -> TimeInterval {
        max(date.timeIntervalSince(startedAt), 0)
    }

    func handleTap(_ number: Int, at date: Date = Date()) -> SchulteTapOutcome {
        guard !completedNumbers.contains(number) else {
            return .ignored
        }

        guard number == nextExpectedNumber else {
            mistakeCount += 1
            return .incorrect(expected: nextExpectedNumber)
        }

        completedNumbers.insert(number)
        nextExpectedNumber += 1

        if completedNumbers.count == totalTiles {
            let finishedAt = max(date, startedAt)
            let result = SchulteSessionResult(
                startedAt: startedAt,
                endedAt: finishedAt,
                duration: finishedAt.timeIntervalSince(startedAt),
                difficulty: config.difficulty,
                mistakeCount: mistakeCount
            )
            return .completed(result)
        }

        return .correct(nextNumber: nextExpectedNumber)
    }
}
