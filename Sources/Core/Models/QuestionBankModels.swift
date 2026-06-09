import Foundation

// MARK: - Section

/// 行测板块 / 题库分区。逻辑推理练习题与考公题库共用同一套题库框架，
/// 通过 `BankSection` 区分题目范围(scope)。
enum BankSection: String, Codable, CaseIterable, Identifiable, Hashable {
    case logicReasoning   // 逻辑推理 / 演绎谜题
    case judgment         // 判断推理（逻辑判断·类比·定义）
    case verbal           // 言语理解与表达
    case quantitative     // 数量关系
    case dataAnalysis     // 资料分析

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .logicReasoning: "逻辑推理"
        case .judgment:       "判断推理"
        case .verbal:         "言语理解"
        case .quantitative:   "数量关系"
        case .dataAnalysis:   "资料分析"
        }
    }

    var systemImage: String {
        switch self {
        case .logicReasoning: "brain.head.profile"
        case .judgment:       "arrow.triangle.branch"
        case .verbal:         "text.book.closed.fill"
        case .quantitative:   "function"
        case .dataAnalysis:   "chart.bar.xaxis"
        }
    }

    /// 对应 `Resources/QuestionBank/<file>.json` 的文件名（不含扩展名）。
    var resourceFileName: String {
        switch self {
        case .logicReasoning: "logic_reasoning"
        case .judgment:       "judgment"
        case .verbal:         "verbal"
        case .quantitative:   "quantitative"
        case .dataAnalysis:   "data_analysis"
        }
    }
}

// MARK: - Question

/// 一道带解析的单选题。逻辑推理谜题与考公各板块都用这一种结构。
struct BankQuestion: Codable, Identifiable, Equatable {
    let id: String
    let section: BankSection
    /// 题型标签，如「演绎推理」「加强论证」「类比推理」「定义判断」「逻辑填空」「片段阅读」「数学运算」。
    let type: String
    /// 难度 1–3。
    let difficulty: Int
    /// 背景 / 资料块（资料分析的图表说明、逻辑谜题的场景与线索）。可为空。
    let material: String?
    /// 题干。
    let stem: String
    /// 选项（通常 4 个）。
    let options: [String]
    /// 正确选项下标。
    let answerIndex: Int
    /// 解析。
    let explanation: String
    /// 可选的解题图示（表格排除法 / 假设法表格 / 结果对应表）——最终解的汇总表。
    var diagram: DiagramTable?
    /// 分步推理：每步一句推导 + 该步的表格快照。用于分步提示与分步解析。
    var steps: [SolutionStep]
    /// 图形推理：题干图形序列（最后一项是待求的“?”）。
    var figurePrompt: [FigureSpec]?
    /// 图形推理：四个图形选项（与 `options`/`answerIndex` 对齐）。
    var figureOptions: [FigureSpec]?
    var tags: [String]
    var source: String?

    /// 是否为图形推理题（选项以图形呈现）。
    var isFigureQuestion: Bool { figureOptions != nil }

    init(
        id: String = UUID().uuidString,
        section: BankSection,
        type: String,
        difficulty: Int,
        material: String? = nil,
        stem: String,
        options: [String],
        answerIndex: Int,
        explanation: String,
        diagram: DiagramTable? = nil,
        steps: [SolutionStep] = [],
        figurePrompt: [FigureSpec]? = nil,
        figureOptions: [FigureSpec]? = nil,
        tags: [String] = [],
        source: String? = nil
    ) {
        self.id = id
        self.section = section
        self.type = type
        self.difficulty = difficulty
        self.material = material
        self.stem = stem
        self.options = options
        self.answerIndex = answerIndex
        self.explanation = explanation
        self.diagram = diagram
        self.steps = steps
        self.figurePrompt = figurePrompt
        self.figureOptions = figureOptions
        self.tags = tags
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case id, section, type, difficulty, material, stem, options, answerIndex, explanation, diagram, steps, figurePrompt, figureOptions, tags, source
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        section = try c.decode(BankSection.self, forKey: .section)
        type = try c.decode(String.self, forKey: .type)
        difficulty = try c.decode(Int.self, forKey: .difficulty)
        material = try c.decodeIfPresent(String.self, forKey: .material)
        stem = try c.decode(String.self, forKey: .stem)
        options = try c.decode([String].self, forKey: .options)
        answerIndex = try c.decode(Int.self, forKey: .answerIndex)
        explanation = try c.decode(String.self, forKey: .explanation)
        diagram = try c.decodeIfPresent(DiagramTable.self, forKey: .diagram)
        steps = try c.decodeIfPresent([SolutionStep].self, forKey: .steps) ?? []
        figurePrompt = try c.decodeIfPresent([FigureSpec].self, forKey: .figurePrompt)
        figureOptions = try c.decodeIfPresent([FigureSpec].self, forKey: .figureOptions)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        source = try c.decodeIfPresent(String.self, forKey: .source)
    }

    /// 同一题在同一会话/最近历史中去重用的指纹。
    var fingerprint: String { id }

    var validationIssues: [String] {
        var issues: [String] = []
        if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("id 不能为空。")
        }
        if stem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("stem 不能为空。")
        }
        if options.count < 2 {
            issues.append("options 至少需要 2 个。")
        }
        if !options.indices.contains(answerIndex) {
            issues.append("answerIndex 越界。")
        }
        if explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("explanation 不能为空。")
        }
        if !(1...3).contains(difficulty) {
            issues.append("difficulty 必须在 1–3 之间。")
        }
        return issues
    }
}

// MARK: - Figure (图形推理：可程序化绘制的简单图形)

/// 可绘制的图形基元，用于「图形推理 / 下一个图形是什么」题型。
enum FigureShape: String, Codable, Equatable {
    case arrow    // 箭头（用 rotation 表示朝向）
    case polygon  // 正多边形（count = 边数）
    case dots     // 一排实心圆点（count = 个数）
    case lines    // 一组水平线段（count = 条数）
    case grid     // 九宫格，前 count 个格子填黑（数量类规律）
}

/// 一个图形的描述。题目把图形序列与选项都用 `FigureSpec` 表达，由 `FigureView` 绘制。
struct FigureSpec: Codable, Equatable {
    var shape: FigureShape
    var count: Int
    var rotation: Double
    var filled: Bool

    init(shape: FigureShape, count: Int = 0, rotation: Double = 0, filled: Bool = false) {
        self.shape = shape
        self.count = count
        self.rotation = rotation
        self.filled = filled
    }

    enum CodingKeys: String, CodingKey { case shape, count, rotation, filled }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        shape = try c.decode(FigureShape.self, forKey: .shape)
        count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
        rotation = try c.decodeIfPresent(Double.self, forKey: .rotation) ?? 0
        filled = try c.decodeIfPresent(Bool.self, forKey: .filled) ?? false
    }
}

// MARK: - Solution diagram (逻辑学导论式的表格排除法 / 假设法表格)

/// 解题图示：一张二维表。行有行标题(`label`)，列有列标题(`columns`)。
/// 既能表达「对应推理的排除网格」（✓/✗），也能表达「真假推理的假设法表格」
/// 与「排序/对应结果表」（文字单元格）。
struct DiagramTable: Codable, Equatable {
    var title: String?
    /// 列标题（不含最左侧的行标题列）。
    var columns: [String]
    var rows: [DiagramRow]
    var caption: String?

    init(title: String? = nil, columns: [String], rows: [DiagramRow], caption: String? = nil) {
        self.title = title
        self.columns = columns
        self.rows = rows
        self.caption = caption
    }
}

struct DiagramRow: Codable, Equatable {
    var label: String
    var cells: [DiagramCell]

    init(label: String, cells: [DiagramCell]) {
        self.label = label
        self.cells = cells
    }
}

/// 一步推理：一句话的推导 + 该步完成后的表格快照（累积填表）。
/// 用于「分步提示」（逐步揭示）与「分步解析」（编号步骤）。
struct SolutionStep: Codable, Equatable {
    var text: String
    var diagram: DiagramTable?

    init(text: String, diagram: DiagramTable? = nil) {
        self.text = text
        self.diagram = diagram
    }
}

/// 单元格。JSON 中用紧凑字符串书写：
/// `"✓"`/`"yes"`/`"真"` → 勾；`"✗"`/`"no"`/`"假"` → 叉；`""` → 空；其余 → 文字。
/// 前缀 `"*"` 表示高亮（最终解）。例如 `"*✓"`、`"*飞行工程师"`。
struct DiagramCell: Equatable {
    enum Kind: Equatable { case yes, no, blank, value }
    var kind: Kind
    var text: String
    var highlight: Bool

    init(kind: Kind, text: String = "", highlight: Bool = false) {
        self.kind = kind
        self.text = text
        self.highlight = highlight
    }
}

extension DiagramCell: Codable {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        var s = raw
        var highlight = false
        if s.hasPrefix("*") { highlight = true; s.removeFirst() }
        switch s {
        case "✓", "yes", "y", "Y", "对", "真", "√":
            self = DiagramCell(kind: .yes, highlight: highlight)
        case "✗", "x", "X", "no", "n", "N", "错", "假", "×":
            self = DiagramCell(kind: .no, highlight: highlight)
        case "":
            self = DiagramCell(kind: .blank, highlight: highlight)
        default:
            self = DiagramCell(kind: .value, text: s, highlight: highlight)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let body: String
        switch kind {
        case .yes:   body = "✓"
        case .no:    body = "✗"
        case .blank: body = ""
        case .value: body = text
        }
        try container.encode((highlight ? "*" : "") + body)
    }
}

// MARK: - Per-type stats (cross-session, for spaced repetition)

/// 题型维度的跨会话正确率统计，用于弱项加权（accuracy < 0.6 且尝试≥3 视为薄弱）。
struct BankTypeStats: Codable, Equatable {
    var totalAttempts: Int = 0
    var correctCount: Int = 0

    var accuracy: Double {
        totalAttempts > 0 ? Double(correctCount) / Double(totalAttempts) : 0
    }

    var isWeak: Bool { totalAttempts >= 3 && accuracy < 0.6 }

    mutating func record(correct: Bool) {
        totalAttempts += 1
        if correct { correctCount += 1 }
    }
}

// MARK: - Metrics

/// 一次题库练习的结果指标。逻辑推理(`.logicReasoning`)与考公(`.civilExam`)两个模块共用。
struct BankPracticeMetrics: Codable, Equatable {
    var section: BankSection
    var difficulty: Int
    var totalQuestions: Int
    var correctCount: Int
    var accuracy: Double
    var perTypeCorrect: [String: Int]
    var perTypeTotal: [String: Int]
    var medianRT: TimeInterval
    var timed: Bool

    init(
        section: BankSection,
        difficulty: Int,
        totalQuestions: Int,
        correctCount: Int,
        accuracy: Double,
        perTypeCorrect: [String: Int] = [:],
        perTypeTotal: [String: Int] = [:],
        medianRT: TimeInterval = 0,
        timed: Bool = false
    ) {
        self.section = section
        self.difficulty = difficulty
        self.totalQuestions = totalQuestions
        self.correctCount = correctCount
        self.accuracy = accuracy
        self.perTypeCorrect = perTypeCorrect
        self.perTypeTotal = perTypeTotal
        self.medianRT = medianRT
        self.timed = timed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        section = try c.decode(BankSection.self, forKey: .section)
        difficulty = try c.decodeIfPresent(Int.self, forKey: .difficulty) ?? 1
        totalQuestions = try c.decode(Int.self, forKey: .totalQuestions)
        correctCount = try c.decode(Int.self, forKey: .correctCount)
        accuracy = try c.decode(Double.self, forKey: .accuracy)
        perTypeCorrect = try c.decodeIfPresent([String: Int].self, forKey: .perTypeCorrect) ?? [:]
        perTypeTotal = try c.decodeIfPresent([String: Int].self, forKey: .perTypeTotal) ?? [:]
        medianRT = try c.decodeIfPresent(TimeInterval.self, forKey: .medianRT) ?? 0
        timed = try c.decodeIfPresent(Bool.self, forKey: .timed) ?? false
    }
}

// MARK: - Library (bundled JSON + imported)

/// 题库加载与查询。内置题来自 `Resources/QuestionBank/*.json`，
/// 与已导入题（`imported`）合并。缺失的板块文件会被安静跳过（分阶段交付：
/// 阶段 1 仅 logic_reasoning.json，考公各板块文件后续补齐）。
enum QuestionBankLibrary {
    private static let bundled: [BankQuestion] = loadAll()

    /// 内置题中已存在的板块（用于 UI 仅展示有内容的板块）。
    static var availableSections: [BankSection] {
        let all = mergedQuestions(imported: [])
        return BankSection.allCases.filter { section in all.contains { $0.section == section } }
    }

    static func mergedQuestions(imported: [BankQuestion]) -> [BankQuestion] {
        // 已导入题以 id 覆盖内置题。
        var byID: [String: BankQuestion] = [:]
        for q in bundled { byID[q.id] = q }
        for q in imported { byID[q.id] = q }
        return Array(byID.values)
    }

    static func questions(
        in sections: [BankSection],
        type: String?,
        imported: [BankQuestion]
    ) -> [BankQuestion] {
        let sectionSet = Set(sections)
        return mergedQuestions(imported: imported).filter { q in
            sectionSet.contains(q.section) && (type == nil || q.type == type)
        }
    }

    /// 某板块内（含已导入）出现过的题型，按内置顺序去重。
    static func types(in section: BankSection, imported: [BankQuestion]) -> [String] {
        var seen: Set<String> = []
        var ordered: [String] = []
        for q in mergedQuestions(imported: imported) where q.section == section {
            if seen.insert(q.type).inserted { ordered.append(q.type) }
        }
        return ordered.sorted()
    }

    private static func loadAll() -> [BankQuestion] {
        var result: [BankQuestion] = []
        for section in BankSection.allCases {
            guard let url = BankResourceLocator.locate(named: section.resourceFileName, extension: "json") else {
                continue // 该板块文件尚未提供，跳过。
            }
            do {
                let data = try Data(contentsOf: url)
                let questions = try JSONDecoder().decode([BankQuestion].self, from: data)
                result.append(contentsOf: questions)
            } catch {
                assertionFailure("Failed to decode \(section.resourceFileName).json: \(error)")
            }
        }
        return result
    }
}

/// 在 App bundle 中定位 `Resources/QuestionBank/<name>.<ext>`。
/// 仿 `ReadingPassageLibrary.locateResource`，但容忍文件缺失（返回 nil 而非 crash）。
enum BankResourceLocator {
    static func locate(named name: String, extension ext: String) -> URL? {
        let bundles = uniqueBundles([Bundle.main, Bundle(for: Marker.self)] + Bundle.allBundles + Bundle.allFrameworks)
        let fileName = "\(name).\(ext)"
        for bundle in bundles {
            if let direct = bundle.url(forResource: name, withExtension: ext) { return direct }
            if let direct = bundle.url(forResource: name, withExtension: ext, subdirectory: "QuestionBank") { return direct }
            if let direct = bundle.url(forResource: name, withExtension: ext, subdirectory: "Resources/QuestionBank") { return direct }
            if let found = recursiveSearch(in: bundle.resourceURL, targetFileName: fileName) { return found }
        }
        return nil
    }

    private static func recursiveSearch(in directoryURL: URL?, targetFileName: String) -> URL? {
        guard let directoryURL else { return nil }
        let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        while let next = enumerator?.nextObject() as? URL {
            if next.lastPathComponent == targetFileName { return next }
        }
        return nil
    }

    private static func uniqueBundles(_ bundles: [Bundle]) -> [Bundle] {
        var seen: Set<String> = []
        return bundles.filter { seen.insert($0.bundleURL.path).inserted }
    }

    private final class Marker {}
}
