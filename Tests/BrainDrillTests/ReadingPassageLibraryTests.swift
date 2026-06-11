import Testing
@testable import BrainDrill

struct ReadingPassageLibraryTests {
    @Test
    func providesSeedBankAcrossAllDifficulties() {
        // 测内置种子库而非 .all：测试宿主是完整 app，.all 会混入本机素材库，结果不可复现。
        let passages = ReadingPassageLibrary.bundled

        #expect(passages.count >= 10)
        #expect(Set(passages.map(\.difficulty)) == [1, 2, 3])
        #expect(passages.filter { $0.difficulty == 1 }.count >= 3)
        #expect(passages.filter { $0.difficulty == 2 }.count >= 3)
        #expect(passages.filter { $0.difficulty == 3 }.count >= 3)
    }

    @Test
    func passageAnnotationsAreComplete() {
        for passage in ReadingPassageLibrary.bundled {
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

    /// 单锚点文章不该出「证据连线到结论」小题——只有 1 个候选时连线题
    /// 退化成单选项废操作。同时素材校验应把这类材料拒之门外。
    @Test
    func singleAnchorPassageSkipsClaimMapping() {
        var base = ReadingPassageLibrary.bundled.first { $0.difficulty >= 2 }!
        #expect(base.requiresClaimMapping)              // 内置文章 ≥2 锚点，正常出连线题
        #expect(!base.evidenceItemsNeedingMapping.isEmpty)

        // 砍到只剩 1 个锚点：连线题整体关闭，校验报错
        let onlyAnchor = base.claimAnchors[0]
        base = ReadingPassage(
            id: base.id, title: base.title, domainTag: base.domainTag,
            difficulty: base.difficulty, structureType: base.structureType, body: base.body,
            mainIdeaOptions: base.mainIdeaOptions, mainIdeaAnswerIndex: base.mainIdeaAnswerIndex,
            mainIdeaRubric: base.mainIdeaRubric,
            claimAnchors: [onlyAnchor],
            evidenceItems: base.evidenceItems,
            recallPrompts: base.recallPrompts, recallKeywords: base.recallKeywords
        )
        #expect(!base.requiresClaimMapping)
        #expect(base.evidenceItemsNeedingMapping.isEmpty)
        #expect(base.validationIssues.contains { $0.contains("结论锚点至少要 2 条") })
    }
}
