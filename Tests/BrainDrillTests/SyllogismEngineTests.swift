import Testing
@testable import BrainDrill

struct SyllogismEngineTests {
    @Test func formalTrainingAvoidsExactRepeatsWithinSession() {
        let engine = SyllogismEngine(difficulty: 1)
        var fingerprints: Set<String> = []

        while !engine.isComplete {
            engine.beginNextTrial()
            guard let trial = engine.currentTrial else {
                break
            }

            #expect(!fingerprints.contains(trial.repetitionFingerprint))
            fingerprints.insert(trial.repetitionFingerprint)

            engine.recordResponse(userSaysValid: trial.isValid)
            engine.advanceToNext()
        }

        #expect(fingerprints.count == engine.totalTrials)
    }

    @Test func trainingAvoidsRecentlySeenItemsAcrossSessions() {
        func runSession(seen: [String]) -> [String] {
            let engine = SyllogismEngine(difficulty: 1, totalTrials: 3, seenFingerprints: seen)
            while !engine.isComplete {
                engine.beginNextTrial()
                guard let trial = engine.currentTrial else { break }
                engine.recordResponse(userSaysValid: trial.isValid)
                engine.advanceToNext()
            }
            return engine.generatedFingerprints
        }

        // First session has no history; the second is seeded with the first's
        // items and must produce entirely different ones (the diff-1 pool is
        // comfortably larger than these two short sessions combined).
        let first = runSession(seen: [])
        #expect(first.count == 3)

        let second = runSession(seen: first)
        #expect(second.count == 3)
        #expect(Set(first).isDisjoint(with: Set(second)))
    }

    /// 每个题型构建出的题目，其有效性必须与题型声明一致——否则按 type.isValid
    /// 分桶的「有效/无效配比控制」会被悄悄破坏。
    @Test func builtTrialValidityMatchesTypeDeclaration() {
        let engine = SyllogismEngine(difficulty: 3)
        for type in SyllogismType.allCases {
            for _ in 0..<8 {
                let trial = engine.buildTrial(type: type)
                #expect(trial.isValid == type.isValid, "\(type) 构建出的题目有效性与类型声明不一致")
                #expect(trial.type == type, "\(type) 构建出的题目类型标注错误")
            }
        }
    }

    /// 因果统计类(E)与论证结构类(F)必须两边都有题型，否则「看到统计场景就点无效」
    /// 这种表面线索能拿分，训练目标失效。等价改写类同理（「等价于」≠必然有效）。
    @Test func surfaceCueFamiliesHaveBothValidAndInvalidTypes() {
        let causal = SyllogismType.allCases.filter { $0.category == .causalStatistical }
        #expect(causal.contains { $0.isValid } && causal.contains { !$0.isValid })

        let argument = SyllogismType.allCases.filter { $0.category == .argumentStructure }
        #expect(argument.contains { $0.isValid } && argument.contains { !$0.isValid })

        // 「等价于」表面线索：等价改写家族中有效/无效都要存在
        let equivalenceFamily: [SyllogismType] = [.contraposition, .converseFallacy, .deMorgan, .deMorganFallacy, .quantifierNegation, .quantifierNegationFallacy]
        #expect(equivalenceFamily.contains { $0.isValid } && equivalenceFamily.contains { !$0.isValid })
    }
}
