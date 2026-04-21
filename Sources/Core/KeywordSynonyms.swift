import Foundation

/// Chinese keyword synonym table for semantic matching in reading training evaluations.
/// Replaces exact substring matching with synonym-aware matching.
enum KeywordSynonyms {
    /// Returns the number of keywords matched (including synonym matches) in the given text.
    static func matchingCount(in text: String, keywords: [String]) -> Int {
        let normalized = normalizeText(text)
        return keywords.filter { keyword in
            let normalizedKeyword = normalizeText(keyword)
            // Direct match
            if normalized.contains(normalizedKeyword) { return true }
            // Synonym match
            let synonyms = findSynonyms(for: normalizedKeyword)
            return synonyms.contains { normalized.contains($0) }
        }.count
    }

    /// Returns how many keywords were matched and the total, for metrics.
    static func matchResult(in text: String, keywords: [String]) -> (matched: Int, total: Int) {
        (matchingCount(in: text, keywords: keywords), keywords.count)
    }

    private static func normalizeText(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }

    private static func findSynonyms(for keyword: String) -> [String] {
        for group in synonymGroups {
            if group.contains(where: { normalizeText($0) == keyword }) {
                return group.map(normalizeText).filter { $0 != keyword }
            }
        }
        return []
    }

    // MARK: - Synonym Groups

    /// Each inner array is a set of synonyms. Order doesn't matter.
    private static let synonymGroups: [[String]] = [
        // Climate & Environment
        ["气候变化", "全球变暖", "气候变暖"],
        ["温室效应", "温室气体效应"],
        ["碳排放", "二氧化碳排放", "CO2排放"],
        ["生态系统", "生态环境", "自然生态"],
        ["可持续发展", "可持续性"],
        ["珊瑚白化", "珊瑚退化"],
        ["冰川消融", "冰川融化", "冰川退缩"],
        ["海平面上升", "海面上升"],

        // Biology & Medicine
        ["基因", "基因组", "遗传基因"],
        ["突变", "基因突变", "变异"],
        ["免疫系统", "免疫机制"],
        ["抗体", "免疫球蛋白"],
        ["新陈代谢", "代谢"],
        ["神经元", "神经细胞"],
        ["神经可塑性", "大脑可塑性"],

        // Physics & Chemistry
        ["原子", "原子结构"],
        ["分子", "分子结构"],
        ["催化剂", "催化作用"],
        ["半导体", "半导体材料"],
        ["量子", "量子力学"],

        // Society & Economy
        ["经济增长", "经济发展"],
        ["通货膨胀", "通胀", "物价上涨"],
        ["失业率", "失业"], 
        ["城市化", "城镇化"],
        ["老龄化", "人口老龄化"],
        ["基础设施", "基建"],

        // Cognition & Psychology
        ["认知", "认知能力"],
        ["记忆", "记忆力"],
        ["注意力", "专注力"],
        ["工作记忆", "短时记忆"],
        ["元认知", "自我认知"],
        ["抑制控制", "抑制能力"],

        // General
        ["影响", "作用", "效应"],
        ["导致", "引起", "造成"],
        ["研究", "研究表明", "研究发现"],
        ["证据", "证明", "实据"],
        ["机制", "机理", "原理"],
        ["策略", "方案", "措施"],
        ["风险", "隐患", "危险"],
        ["恢复力", "韧性", "弹性"],
        ["评估", "评价", "衡量"],
        ["优化", "改进", "改善"],
    ]
}
