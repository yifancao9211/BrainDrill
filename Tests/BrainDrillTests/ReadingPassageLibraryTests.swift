import Testing
@testable import BrainDrill

struct ReadingPassageLibraryTests {
    @Test
    func providesSeedBankAcrossAllDifficulties() {
        let passages = ReadingPassageLibrary.all

        #expect(passages.count >= 10)
        #expect(Set(passages.map(\.difficulty)) == [1, 2, 3])
        #expect(passages.filter { $0.difficulty == 1 }.count >= 3)
        #expect(passages.filter { $0.difficulty == 2 }.count >= 3)
        #expect(passages.filter { $0.difficulty == 3 }.count >= 3)
    }

    @Test
    func passageAnnotationsAreComplete() {
        for passage in ReadingPassageLibrary.all {
            #expect(passage.mainIdeaOptions.count == 4)
            #expect(passage.mainIdeaOptions.indices.contains(passage.mainIdeaAnswerIndex))
            #expect(passage.claimAnchors.count >= 2)
            #expect(passage.evidenceItems.count >= 4)
            #expect(passage.recallPrompts.count >= 5)
            #expect(passage.recallKeywords.count >= 5)
        }
    }

    @Test
    func randomPassageRespectsDifficultyCap() {
        for _ in 0..<10 {
            let passage = ReadingPassageLibrary.randomPassage(maxDifficulty: 2)
            #expect(passage.difficulty <= 2)
        }
    }
}
