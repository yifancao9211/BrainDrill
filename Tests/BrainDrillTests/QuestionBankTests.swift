import Testing
import Foundation
@testable import BrainDrill

struct QuestionBankTests {
    private func makeQuestion(id: String, type: String = "对应推理", difficulty: Int = 1, answerIndex: Int = 0) -> BankQuestion {
        BankQuestion(
            id: id,
            section: .logicReasoning,
            type: type,
            difficulty: difficulty,
            stem: "题干 \(id)",
            options: ["A", "B", "C", "D"],
            answerIndex: answerIndex,
            explanation: "解析"
        )
    }

    @Test
    func bundledLogicReasoningBankLoadsAndIsValid() {
        let questions = QuestionBankLibrary.questions(in: [.logicReasoning], type: nil, imported: [])
        #expect(questions.count >= 10)
        for q in questions {
            #expect(q.validationIssues.isEmpty)
            #expect(q.options.indices.contains(q.answerIndex))
        }
        // 内置板块仅 logic_reasoning，应只出现该板块。
        #expect(QuestionBankLibrary.availableSections.contains(.logicReasoning))
    }

    @Test
    func importedQuestionsOverrideBundledByID() {
        let bundledFirst = QuestionBankLibrary.questions(in: [.logicReasoning], type: nil, imported: []).first!
        let override = makeQuestion(id: bundledFirst.id, answerIndex: 3)
        let merged = QuestionBankLibrary.questions(in: [.logicReasoning], type: nil, imported: [override])
        let updated = merged.first { $0.id == bundledFirst.id }
        #expect(updated?.answerIndex == 3)
        // 数量不变（覆盖而非追加）。
        #expect(merged.count == QuestionBankLibrary.questions(in: [.logicReasoning], type: nil, imported: []).count)
    }

    @Test
    func selectorAvoidsRecentAndRespectsCount() {
        let pool = (1...10).map { makeQuestion(id: "q\($0)") }
        let recent = Set(["q1", "q2", "q3"])
        let picked = QuestionSelector.pick(
            from: pool,
            count: 5,
            recentFingerprints: recent,
            weakTypes: [],
            randomSource: { 0.0 }
        )
        #expect(picked.count == 5)
        // 有足够新题时不应选到近期题。
        #expect(picked.allSatisfy { !recent.contains($0.id) })
    }

    @Test
    func engineScoresAndComputesMetrics() {
        let questions = [
            makeQuestion(id: "a", type: "对应推理", answerIndex: 0),
            makeQuestion(id: "b", type: "排序推理", answerIndex: 1),
        ]
        // 两题难度相同（默认 1），按 id 升序先 "a" 后 "b"。
        let engine = QuestionBankEngine(pool: questions, section: .logicReasoning, targetCount: 2, startDifficulty: 1.0)

        engine.select(0)            // "a" 正确
        engine.advance()
        engine.select(3)            // "b" 错误（正确是 1）
        engine.advance()
        #expect(engine.isComplete)

        let metrics = engine.computeMetrics()
        #expect(metrics.totalQuestions == 2)
        #expect(metrics.correctCount == 1)
        #expect(abs(metrics.accuracy - 0.5) < 0.0001)
        #expect(metrics.perTypeCorrect["对应推理"] == 1)
        #expect(metrics.perTypeTotal["排序推理"] == 1)
    }

    private func mixedPool() -> [BankQuestion] {
        var pool: [BankQuestion] = []
        for d in 1...3 {
            for i in 0..<5 { pool.append(makeQuestion(id: "d\(d)-\(i)", difficulty: d, answerIndex: 0)) }
        }
        return pool
    }

    @Test
    func startDifficultyPicksNearestQuestion() {
        let pool = mixedPool()
        let easy = QuestionBankEngine(pool: pool, section: .logicReasoning, targetCount: 3, startDifficulty: 1.0)
        let hard = QuestionBankEngine(pool: pool, section: .logicReasoning, targetCount: 3, startDifficulty: 3.0)
        #expect(easy.currentQuestion?.difficulty == 1)
        #expect(hard.currentQuestion?.difficulty == 3)
    }

    @Test
    func adaptiveDifficultyRisesOnCorrectFallsOnWrong() {
        let engine = QuestionBankEngine(pool: mixedPool(), section: .logicReasoning, targetCount: 6, startDifficulty: 2.0)
        #expect(engine.currentQuestion?.difficulty == 2)

        let before = engine.currentDifficulty
        engine.select(0); engine.advance()          // 答对 → 变难
        #expect(engine.currentDifficulty > before)

        let mid = engine.currentDifficulty
        engine.select(99); engine.advance()         // 答错 → 变易
        #expect(engine.currentDifficulty < mid)
        #expect(engine.currentDifficulty >= 1)
    }

    @Test
    func bundledCivilExamBanksLoadAndAreValid() {
        let examSections: [BankSection] = [.judgment, .verbal, .quantitative, .dataAnalysis]
        let questions = QuestionBankLibrary.questions(in: examSections, type: nil, imported: [])
        #expect(questions.count >= 10)
        for q in questions {
            #expect(q.validationIssues.isEmpty)
            #expect(q.options.indices.contains(q.answerIndex))
        }
        // 每个行测板块都至少有题。
        for section in examSections {
            let inSection = questions.filter { $0.section == section }
            #expect(!inSection.isEmpty)
        }
        // 全部内置板块（含逻辑推理）都应可见。
        let available = Set(QuestionBankLibrary.availableSections)
        #expect(available.isSuperset(of: Set(examSections + [.logicReasoning])))
    }

    @Test
    func figureReasoningQuestionsLoadWithMatchedOptions() {
        let judgment = QuestionBankLibrary.questions(in: [.judgment], type: nil, imported: [])
        let figures = judgment.filter { $0.isFigureQuestion }
        #expect(figures.count >= 4)
        for q in figures {
            #expect(q.figureOptions?.count == q.options.count)   // 图形选项与选项对齐
            #expect(q.figurePrompt?.isEmpty == false)            // 有题干序列
            #expect(q.options.indices.contains(q.answerIndex))
            #expect(q.validationIssues.isEmpty)
        }
    }

    @Test
    func diagramCellCompactStringParsing() throws {
        func decode(_ s: String) throws -> DiagramCell {
            try JSONDecoder().decode(DiagramCell.self, from: Data("\"\(s)\"".utf8))
        }
        #expect(try decode("✓").kind == .yes)
        #expect(try decode("真").kind == .yes)
        #expect(try decode("✗").kind == .no)
        #expect(try decode("假").kind == .no)
        #expect(try decode("").kind == .blank)
        let v = try decode("*飞行工程师")
        #expect(v.kind == .value)
        #expect(v.text == "飞行工程师")
        #expect(v.highlight == true)
        // round-trip
        let data = try JSONEncoder().encode(v)
        let again = try JSONDecoder().decode(DiagramCell.self, from: data)
        #expect(again == v)
    }

    @Test
    func bundledStepDiagramsAreWellFormed() {
        // 部分逻辑题配表格图示（网格/假设法表）；这些表格行列必须对齐。
        let questions = QuestionBankLibrary.questions(in: [.logicReasoning], type: nil, imported: [])
        let diagrams = questions.flatMap { $0.steps.compactMap(\.diagram) }
        #expect(!diagrams.isEmpty)
        for d in diagrams {
            for row in d.rows {
                #expect(row.cells.count == d.columns.count)
            }
        }
    }

    @Test
    func bundledQuestionsCarryStepwiseSolutions() {
        let questions = QuestionBankLibrary.questions(in: [.logicReasoning], type: nil, imported: [])
        for q in questions {
            #expect(!q.steps.isEmpty) // 每题都有分步解析
            for step in q.steps {
                #expect(!step.text.trimmingCharacters(in: .whitespaces).isEmpty)
                if let d = step.diagram {
                    for row in d.rows {
                        #expect(row.cells.count == d.columns.count)
                    }
                }
            }
        }
    }

    @Test
    func metricsRoundTripThroughModuleMetrics() throws {
        let metrics = BankPracticeMetrics(
            section: .logicReasoning,
            difficulty: 2,
            totalQuestions: 5,
            correctCount: 4,
            accuracy: 0.8
        )
        let wrapped = ModuleMetrics.questionBank(metrics)
        let data = try JSONEncoder().encode(wrapped)
        let decoded = try JSONDecoder().decode(ModuleMetrics.self, from: data)
        if case let .questionBank(m) = decoded {
            #expect(m.section == .logicReasoning)
            #expect(m.correctCount == 4)
        } else {
            Issue.record("decoded metrics was not .questionBank")
        }
    }
}
