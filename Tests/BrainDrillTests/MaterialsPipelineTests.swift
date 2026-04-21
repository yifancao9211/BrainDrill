import Foundation
import Testing
@testable import BrainDrill

struct MaterialsPipelineTests {
    @Test
    func readingRepositoryMergesApprovedPassagesOverBundledContent() {
        let custom = ReadingPassage(
            id: "microplastic-river",
            title: "自定义微塑料材料",
            domainTag: "环境科学",
            difficulty: 2,
            structureType: .causeEffect,
            body: "本地正式库应该覆盖同 id 的内置材料。",
            mainIdeaOptions: ["a", "b", "c", "d"],
            mainIdeaAnswerIndex: 0,
            mainIdeaRubric: MainIdeaRubric(idealSummary: "summary", keywords: ["本地", "覆盖", "材料", "正式", "题库"], trapNote: "trap"),
            claimAnchors: [
                ReadingClaimAnchor(id: "claim-1", text: "本地材料覆盖内置材料。", scope: .global),
                ReadingClaimAnchor(id: "claim-2", text: "同 id 时优先本地版本。", scope: .local)
            ],
            evidenceItems: [
                EvidenceClassificationItem(id: "e1", text: "存在同 id。", role: .background, supportsClaimID: nil),
                EvidenceClassificationItem(id: "e2", text: "读取合并库。", role: .evidence, supportsClaimID: "claim-1"),
                EvidenceClassificationItem(id: "e3", text: "本地材料优先。", role: .claim, supportsClaimID: nil),
                EvidenceClassificationItem(id: "e4", text: "读取结果已替换。", role: .evidence, supportsClaimID: "claim-2")
            ],
            recallPrompts: [
                DelayedRecallPrompt(id: "r1", text: "本地正式库可覆盖内置库。", isTarget: true),
                DelayedRecallPrompt(id: "r2", text: "同 id 时永远保留内置库。", isTarget: false),
                DelayedRecallPrompt(id: "r3", text: "合并库会优先取本地版本。", isTarget: true),
                DelayedRecallPrompt(id: "r4", text: "本地入库后会参与阅读模块抽题。", isTarget: true),
                DelayedRecallPrompt(id: "r5", text: "正式库不会影响题库读取。", isTarget: false)
            ],
            recallKeywords: ["本地", "覆盖", "内置", "正式", "题库"]
        )

        let approved = ApprovedReadingPassage(
            passage: custom,
            sourceArticle: SourceArticle(
                sourceKind: .ourWorldInData,
                title: "source",
                url: "https://example.com/material",
                summary: "summary",
                excerpt: "excerpt"
            ),
            approvedAt: Date(),
            candidateID: "candidate-1",
            score: 88
        )

        ReadingPassageRepository.updateApprovedPassages([approved])
        let merged = ReadingPassageLibrary.all

        #expect(merged.first(where: { $0.id == "microplastic-river" })?.title == "自定义微塑料材料")

        ReadingPassageRepository.updateApprovedPassages([])
    }

    @Test
    func passageValidationFlagsBrokenSupportsClaimLinks() {
        let invalid = ReadingPassage(
            id: "invalid-passage",
            title: "invalid",
            domainTag: "测试",
            difficulty: 2,
            structureType: .mechanism,
            body: "这是一篇故意构造的无效材料。",
            mainIdeaOptions: ["a", "b", "c", "d"],
            mainIdeaAnswerIndex: 0,
            mainIdeaRubric: MainIdeaRubric(idealSummary: "summary", keywords: ["一", "二", "三", "四", "五"], trapNote: "trap"),
            claimAnchors: [
                ReadingClaimAnchor(id: "claim-1", text: "只有一条结论。", scope: .global)
            ],
            evidenceItems: [
                EvidenceClassificationItem(id: "e1", text: "错误映射", role: .evidence, supportsClaimID: "missing-claim"),
                EvidenceClassificationItem(id: "e2", text: "claim", role: .claim, supportsClaimID: nil),
                EvidenceClassificationItem(id: "e3", text: "background", role: .background, supportsClaimID: nil),
                EvidenceClassificationItem(id: "e4", text: "limitation", role: .limitation, supportsClaimID: nil)
            ],
            recallPrompts: [
                DelayedRecallPrompt(id: "r1", text: "1", isTarget: true),
                DelayedRecallPrompt(id: "r2", text: "2", isTarget: false),
                DelayedRecallPrompt(id: "r3", text: "3", isTarget: true),
                DelayedRecallPrompt(id: "r4", text: "4", isTarget: true),
                DelayedRecallPrompt(id: "r5", text: "5", isTarget: false)
            ],
            recallKeywords: ["一", "二", "三", "四", "五"]
        )

        #expect(invalid.validationIssues.contains { $0.contains("supportsClaimID") })
    }

    @Test
    func materialCandidatePrefersLocalizedChineseContentForDisplay() {
        let candidate = MaterialCandidate(
            sourceArticle: SourceArticle(
                sourceKind: .nasa,
                title: "How solar storms disrupt satellites",
                url: "https://example.com/solar-storms",
                summary: "summary",
                excerpt: "excerpt"
            ),
            generatedPassage: nil,
            localizedTitle: "太阳风暴如何干扰卫星",
            generatedSummary: "太阳风暴会扰动地球附近的带电粒子环境，从而影响卫星通信与导航稳定性。",
            score: 0,
            ruleScore: 0,
            aiScore: 0,
            suggestedDifficulty: 2,
            failureReasons: ["AI 返回了不兼容的响应格式。"],
            debugLogs: ["OpenAI 端点失败"],
            cleaningModel: "claude-opus-4-6"
        )

        #expect(candidate.displayTitle == "太阳风暴如何干扰卫星")
        #expect(candidate.displaySummary.contains("太阳风暴"))
        #expect(candidate.resolvedDebugLogs == ["OpenAI 端点失败"])
    }

    @Test
    func partyStateSourceRulesMatchCurrentArticlePaths() {
        #expect(
            ConcreteSourceKind.ccps.acceptsCandidateURL(
                URL(string: "https://www.ccps.gov.cn/xwpd/rdxw/202603/t20260323_170425.shtml")!
            )
        )
        #expect(
            ConcreteSourceKind.studyTimes.acceptsCandidateURL(
                URL(string: "https://www.studytimes.cn/llsd/202603/t20260324_86781.html")!
            )
        )
    }

    @Test
    func materialCandidateDisplaySummaryIsClippedForWorkbenchPerformance() {
        let candidate = MaterialCandidate(
            sourceArticle: SourceArticle(
                sourceKind: .qstheory,
                title: "source",
                url: "https://example.com/article",
                summary: "summary",
                excerpt: String(repeating: "甲", count: 2_000)
            ),
            generatedPassage: nil,
            generatedSummary: String(repeating: "乙", count: 1_800),
            score: 0,
            ruleScore: 0,
            aiScore: 0,
            suggestedDifficulty: 2,
            cleaningModel: "claude-opus-4-6"
        )

        #expect(candidate.displaySummary.count == 1_200)
    }

    @Test
    func generatedPassagePayloadNormalizesCommonAIRoleSynonyms() throws {
        let json = """
        {
          "title": "测试标题",
          "difficulty": "2",
          "mainIdeaOptions": ["A", "B", "C", "D"],
          "mainIdeaAnswerIndex": "1",
          "mainIdeaRubric": {
            "idealSummary": "总结",
            "keywords": ["一", "二"],
            "trapNote": "陷阱"
          },
          "claimAnchors": [
            { "id": "claim-1", "text": "总论点", "scope": "overall" }
          ],
          "evidenceItems": [
            { "id": "e1", "text": "限制项", "role": "concession", "supportsClaimID": "claim-1" }
          ],
          "recallPrompts": [
            { "id": "r1", "text": "提示", "isTarget": true }
          ],
          "recallKeywords": ["关键词"],
          "aiSelfScore": "88",
          "scoreReason": "可用",
          "riskNotes": []
        }
        """

        let payload = try JSONDecoder().decode(GeneratedPassagePayload.self, from: Data(json.utf8))

        #expect(payload.difficulty == 2)
        #expect(payload.mainIdeaAnswerIndex == 1)
        #expect(payload.claimAnchors.first?.scope == .global)
        #expect(payload.evidenceItems.first?.role == .limitation)
        #expect(payload.aiSelfScore == 88)
    }
}
