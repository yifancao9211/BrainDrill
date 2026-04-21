import Foundation

/// Generates `LogicArgumentPassage` from source articles via a two-pass AI pipeline
/// with automated consistency checking.
struct LogicArgumentCleaner: Sendable {

    let client: AIClient

    init(client: AIClient) {
        self.client = client
    }

    // MARK: - Public API

    /// Full two-pass generation: Pass 1 generates structure, Pass 2 verifies consistency.
    /// Returns validated passage + consistency check result.
    func generatePassage(
        from article: SourceArticle,
        difficulty: Int,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> LogicArgumentCleanerResult {
        let report = onProgress ?? { _ in }

        // Pass 1: Generate argument passage
        report("🔧 Pass 1/2：生成论证结构...")
        let pass1Result = try await client.requestJSON(
            system: "你只输出严格 JSON，不要解释。",
            user: Self.pass1Prompt(article: article, difficulty: difficulty),
            responseType: GeneratedLogicPassage.self,
            stage: "论证生成"
        )
        let generated = pass1Result.value
        report("✅ Pass 1 完成：\(generated.title)")

        let passage = LogicArgumentPassage(
            id: StableMaterialID.make(prefix: "la_gen", seed: article.url),
            title: generated.title,
            domainTag: generated.domainTag,
            difficulty: difficulty,
            body: generated.body,
            argumentComponents: generated.argumentComponents,
            fallacyItems: generated.fallacyItems,
            evaluationItems: generated.evaluationItems
        )

        // Rule-based validation
        let ruleIssues = LogicArgumentValidation.validate(passage)
        if !ruleIssues.isEmpty {
            report("⚠️ 规则校验发现 \(ruleIssues.count) 个问题")
        }

        // Pass 2: Independent consistency verification
        report("🔍 Pass 2/2：一致性校验...")
        let consistencyResult: ConsistencyCheckResult
        do {
            let pass2Result = try await client.requestJSON(
                system: "你只输出严格 JSON，不要解释。",
                user: Self.pass2VerifyPrompt(passage: passage),
                responseType: ConsistencyCheckResult.self,
                stage: "一致性校验"
            )
            consistencyResult = pass2Result.value
            report("✅ Pass 2 完成：结构一致 \(Int(consistencyResult.structureAgreement * 100))%")
        } catch {
            // If Pass 2 fails, still return Pass 1 result with degraded confidence
            report("⚠️ Pass 2 校验请求失败，降级为仅 Pass 1 结果")
            consistencyResult = ConsistencyCheckResult(
                structureAgreement: 0.5,
                fallacyAgreement: false,
                assumptionAgreement: false,
                disagreementDetails: ["Pass 2 校验请求失败: \(error.localizedDescription)"]
            )
        }

        let score = computeQualityScore(passage: passage, consistency: consistencyResult, ruleIssues: ruleIssues)
        report("📊 质量评分：\(Int(score))/100")

        return LogicArgumentCleanerResult(
            passage: passage,
            consistency: consistencyResult,
            qualityScore: score,
            ruleIssues: ruleIssues,
            logs: pass1Result.logs + ["一致性结构 \(Int(consistencyResult.structureAgreement * 100))%"]
        )
    }

    // MARK: - Quality Score

    private func computeQualityScore(
        passage: LogicArgumentPassage,
        consistency: ConsistencyCheckResult,
        ruleIssues: [String]
    ) -> Double {
        var score = 0.0

        // Structure completeness (25 pts)
        let hasPremise = passage.argumentComponents.contains { $0.role == .premise }
        let hasConclusion = passage.argumentComponents.contains { $0.role == .conclusion }
        score += hasPremise ? 12 : 0
        score += hasConclusion ? 13 : 0

        // Fallacy quality (25 pts)
        let fallacyOK = passage.fallacyItems.allSatisfy { $0.distractors.count == 3 }
        score += passage.fallacyItems.isEmpty ? 0 : (fallacyOK ? 25 : 15)

        // Evaluation quality (20 pts, difficulty 2+ only)
        if passage.difficulty >= 2 {
            let evalOK = passage.evaluationItems.allSatisfy {
                $0.assumptionOptions.count == 4 && $0.assumptionOptions.indices.contains($0.correctAssumptionIndex)
            }
            score += passage.evaluationItems.isEmpty ? 0 : (evalOK ? 20 : 10)
        } else {
            score += 20 // full marks for difficulty 1 (no eval required)
        }

        // Consistency bonus (20 pts)
        score += consistency.structureAgreement * 10
        score += consistency.fallacyAgreement ? 5 : 0
        score += consistency.assumptionAgreement ? 5 : 0

        // Penalty for rule issues (up to -10)
        score -= Double(min(ruleIssues.count * 3, 10))

        return max(0, min(score, 100))
    }

    // MARK: - Prompts

    static func pass1Prompt(article: SourceArticle, difficulty: Int) -> String {
        let evalInstructions: String
        if difficulty >= 2 {
            evalInstructions = """
            由于难度为 \(difficulty)，你必须在 evaluationItems 中提供至少 1 道评估题，包含：
            - argumentText：被评估的论点
            - hiddenAssumption：隐含假设的正确答案
            - assumptionOptions：恰好 4 个选项（含正确答案）
            - correctAssumptionIndex：正确选项的索引（0-3）
            - modifierStatements：至少 3 条修饰语句（加强/削弱/无关各至少 1 条）
            """
        } else {
            evalInstructions = "由于难度为 1，evaluationItems 可以为空数组 []。"
        }

        return """
        你是一位严谨的逻辑学教授，正在为批判性思维训练设计论证分析题。

        基于以下文章，生成一个完整的论证分析训练材料。

        约束：
        1. 仅输出 JSON。不要输出 Markdown，不要输出 ```json 代码块，不要输出解释文字。
        2. body 必须是完整的中文论述段落（400-1200字），包含明确的论证结构。
        3. argumentComponents 至少包含 4 个组件，必须包含至少 1 个 premise 和 1 个 conclusion。
        4. 每个 argumentComponent 的 text 必须出自 body 正文中的原句或近义改写。
        5. fallacyItems 至少包含 1 道谬误识别题。每道题必须有 correctFallacy 和恰好 3 个 distractors。
        6. correctFallacy 和 distractors 只能使用以下值：adHominem, strawMan, falseDisjunction, slipperySlope, appealToAuthority, appealToEmotion, hastyGeneralization, circularReasoning, redHerring, falseCause, equivocation, appealToTradition, bandwagon, noFallacy
        7. \(evalInstructions)
        8. modifierStatements 中 type 只能是 strengthen / weaken / irrelevant
        9. argumentComponent 中 role 只能是 premise / conclusion / subConclusion / background / counterpoint
        10. id 使用 "gen_" 开头的唯一标识符

        JSON 结构：
        {
          "title": "中文标题",
          "domainTag": "领域标签",
          "body": "完整论述正文",
          "argumentComponents": [
            {"id": "gen_c1", "text": "组件文本", "role": "premise", "supportsConclusionID": null}
          ],
          "fallacyItems": [
            {"id": "gen_f1", "argumentText": "含谬误的论述", "correctFallacy": "falseCause", "distractors": ["strawMan", "adHominem", "noFallacy"], "explanation": "解释"}
          ],
          "evaluationItems": []
        }

        来源标题：\(article.title)
        来源正文：
        \(article.aiInputText.prefix(3000))
        """
    }

    static func pass2VerifyPrompt(passage: LogicArgumentPassage) -> String {
        let componentsJSON = passage.argumentComponents.map { c in
            "  {\"id\": \"\(c.id)\", \"text\": \"\(c.text.prefix(60))...\", \"role\": \"\(c.role.rawValue)\"}"
        }.joined(separator: ",\n")

        let fallacyJSON = passage.fallacyItems.map { f in
            "  {\"id\": \"\(f.id)\", \"argumentText\": \"\(f.argumentText.prefix(60))...\", \"correctFallacy\": \"\(f.correctFallacy.rawValue)\"}"
        }.joined(separator: ",\n")

        let evalJSON = passage.evaluationItems.map { e in
            let assumIdx = e.correctAssumptionIndex
            let assumText = e.assumptionOptions.indices.contains(assumIdx) ? e.assumptionOptions[assumIdx] : "N/A"
            return "  {\"id\": \"\(e.id)\", \"hiddenAssumption\": \"\(e.hiddenAssumption.prefix(60))...\", \"correctAnswer\": \"\(assumText.prefix(60))...\"}"
        }.joined(separator: ",\n")

        return """
        你是逻辑学审核专家，请独立审核以下论证分析题的正确性。仅输出 JSON，不要其他内容。

        给定材料：
        标题：\(passage.title)
        正文：\(passage.body.prefix(800))

        结构标注：
        [\(componentsJSON)]

        谬误侦测：
        [\(fallacyJSON)]

        评估题：
        [\(evalJSON)]

        请回答：
        1. structureAgreement (0.0-1.0)：你独立分析后认为结构标注的准确比例
        2. fallacyAgreement (true/false)：所有谬误题的 correctFallacy 是否正确
        3. assumptionAgreement (true/false)：评估题中的隐含假设和正确答案是否正确
        4. disagreementDetails：如有分歧，列出具体分歧说明

        输出 JSON：
        {
          "structureAgreement": 0.9,
          "fallacyAgreement": true,
          "assumptionAgreement": true,
          "disagreementDetails": []
        }
        """
    }
}

// MARK: - Generated Types

struct GeneratedLogicPassage: Codable, Sendable {
    let title: String
    let domainTag: String
    let body: String
    let argumentComponents: [ArgumentComponent]
    let fallacyItems: [FallacyDetectionItem]
    let evaluationItems: [ArgumentEvaluationItem]
}

struct LogicArgumentCleanerResult: Sendable {
    let passage: LogicArgumentPassage
    let consistency: ConsistencyCheckResult
    let qualityScore: Double
    let ruleIssues: [String]
    let logs: [String]
}
