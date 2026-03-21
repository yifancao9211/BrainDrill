import Foundation
import Testing
@testable import BrainDrill

struct SchulteEngineTests {
    @Test
    func generatesUniqueTilesForDifficulty() {
        let engine = SchulteEngine(
            config: SchulteSessionConfig(difficulty: .challenge5x5, showHints: true, startMode: .manual)
        )
        #expect(engine.tiles.count == 25)
        #expect(Set(engine.tiles.map(\.number)).count == 25)
        #expect(engine.tiles.map(\.number).sorted() == Array(1...25))
    }

    @Test
    func progressesThroughCorrectSequenceAndCompletes() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let engine = SchulteEngine(
            config: SchulteSessionConfig(difficulty: .easy3x3, showHints: true, startMode: .manual),
            startedAt: startedAt,
            tiles: (1...9).map { SchulteTile(number: $0) }
        )

        for number in 1..<9 {
            let outcome = engine.handleTap(number, at: startedAt.addingTimeInterval(TimeInterval(number)))
            if case let .correct(nextNumber) = outcome {
                #expect(nextNumber == number + 1)
            } else {
                Issue.record("Expected correct outcome for \(number)")
            }
        }

        let outcome = engine.handleTap(9, at: startedAt.addingTimeInterval(12))
        if case let .completed(result) = outcome {
            #expect(result.duration == 12)
            #expect(result.mistakeCount == 0)
            #expect(result.difficulty == .easy3x3)
        } else {
            Issue.record("Expected completion on the last number")
        }
    }

    @Test
    func countsMistakesWithoutAdvancingState() {
        let startedAt = Date(timeIntervalSince1970: 500)
        let engine = SchulteEngine(
            config: SchulteSessionConfig(difficulty: .easy3x3, showHints: false, startMode: .manual),
            startedAt: startedAt,
            tiles: (1...9).map { SchulteTile(number: $0) }
        )

        let firstOutcome = engine.handleTap(4, at: startedAt.addingTimeInterval(1))
        if case let .incorrect(expected) = firstOutcome {
            #expect(expected == 1)
        } else {
            Issue.record("Expected incorrect outcome for wrong tap")
        }

        #expect(engine.mistakeCount == 1)
        #expect(engine.nextExpectedNumber == 1)
    }

    @Test
    func generates8x8and9x9Tiles() {
        let e8 = SchulteEngine(config: SchulteSessionConfig(difficulty: .elite8x8, showHints: false, startMode: .manual))
        #expect(e8.tiles.count == 64)

        let e9 = SchulteEngine(config: SchulteSessionConfig(difficulty: .legend9x9, showHints: false, startMode: .manual))
        #expect(e9.tiles.count == 81)
    }
}
