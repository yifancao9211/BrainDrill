import Foundation
import Darwin
import SQLite3

struct BrainDrillCLI {
    static func main() {
        do {
            try run(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch let error as CLIError {
            emitFailure(code: error.code, message: error.message, details: error.details)
            exit(1)
        } catch {
            emitFailure(code: "unexpected_error", message: error.localizedDescription, details: nil)
            exit(1)
        }
    }

    private static func run(arguments: [String]) throws {
        guard let command = arguments.first else {
            emitSuccess(HelpResponse(usage: usageText))
            return
        }

        switch command {
        case "help", "--help", "-h":
            emitSuccess(HelpResponse(usage: usageText))
        case "store":
            try runStoreCommand(Array(arguments.dropFirst()))
        case "passages":
            try runPassagesCommand(Array(arguments.dropFirst()))
        case "syllogisms":
            try runSyllogismsCommand(Array(arguments.dropFirst()))
        case "sqlite":
            try runSQLiteCommand(Array(arguments.dropFirst()))
        default:
            throw CLIError(code: "unknown_command", message: "未知命令：\(command)", details: usageText)
        }
    }

    private static func runSyllogismsCommand(_ arguments: [String]) throws {
        guard let subcommand = arguments.first else {
            throw CLIError(code: "missing_syllogisms_command", message: "syllogisms 需要子命令。", details: "list | import | delete")
        }

        let store = CLIStore.live()
        switch subcommand {
        case "list":
            let rows = try listSyllogisms(store: store)
            emitSuccess(SyllogismListResponse(count: rows.count, syllogisms: rows))
        case "add", "import":
            let trial = try makeSyllogismTrial(from: Array(arguments.dropFirst()))
            emitSuccess(try upsertSyllogism(trial, store: store))
        case "delete":
            guard arguments.count >= 2 else {
                throw CLIError(code: "missing_syllogism_id", message: "缺少逻辑题 ID。", details: "braindrillctl syllogisms delete trial-id")
            }
            emitSuccess(try deleteSyllogism(id: arguments[1], store: store))
        default:
            throw CLIError(code: "unknown_syllogisms_command", message: "未知 syllogisms 子命令：\(subcommand)", details: "list | import | delete")
        }
    }

    private static func runStoreCommand(_ arguments: [String]) throws {
        guard arguments.first == "path" else {
            throw CLIError(code: "invalid_store_command", message: "store 只支持 path 子命令。", details: "braindrillctl store path")
        }
        emitSuccess(StorePathResponse(path: CLIStore.live().storageURL.path))
    }

    private static func runSQLiteCommand(_ arguments: [String]) throws {
        guard let subcommand = arguments.first else {
            throw CLIError(
                code: "missing_sqlite_command",
                message: "sqlite 需要子命令。",
                details: "path | command | exec SQL"
            )
        }

        let store = CLIStore.live()
        switch subcommand {
        case "path":
            emitSuccess(StorePathResponse(path: store.storageURL.path))
        case "command":
            emitSuccess(SQLiteCommandResponse(command: "sqlite3 \(shellQuote(store.storageURL.path))"))
        case "exec":
            let sql: String
            let inlineSQL = Array(arguments.dropFirst()).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if inlineSQL.isEmpty {
                try rejectRegularFileStdin(
                    code: "sqlite_stdin_file_forbidden",
                    message: "sqlite exec 禁止从磁盘文件读取 SQL。",
                    details: "请使用命令参数或管道直接传入 SQL，例如：braindrillctl sqlite exec \"SELECT COUNT(*) FROM syllogism_trials\"；不要使用 braindrillctl sqlite exec < import.sql。"
                )
                let input = FileHandle.standardInput.readDataToEndOfFile()
                guard let stdinSQL = String(data: input, encoding: .utf8),
                      !stdinSQL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw CLIError(code: "empty_sqlite_input", message: "sqlite exec 需要 SQL。", details: nil)
                }
                sql = stdinSQL
            } else {
                sql = inlineSQL
            }
            emitSuccess(try store.executeSQL(sql))
        default:
            throw CLIError(
                code: "unknown_sqlite_command",
                message: "未知 sqlite 子命令：\(subcommand)",
                details: "path | command | exec SQL"
            )
        }
    }

    private static func runPassagesCommand(_ arguments: [String]) throws {
        guard let subcommand = arguments.first else {
            throw CLIError(code: "missing_passages_command", message: "passages 需要子命令。", details: "list | import | delete")
        }

        let store = CLIStore.live()
        switch subcommand {
        case "list":
            let rows = try listPassages(store: store)
            emitSuccess(PassageListResponse(count: rows.count, passages: rows))
        case "add", "import":
            let passage = try makeReadingPassage(from: Array(arguments.dropFirst()))
            emitSuccess(try upsertPassage(passage, store: store))
        case "delete":
            guard arguments.count >= 2 else {
                throw CLIError(code: "missing_passage_id", message: "缺少素材 ID。", details: "braindrillctl passages delete passage-id")
            }
            let result = try deletePassage(id: arguments[1], store: store)
            emitSuccess(result)
        default:
            throw CLIError(code: "unknown_passages_command", message: "未知 passages 子命令：\(subcommand)", details: "list | import | delete")
        }
    }

    private static func rejectRegularFileStdin(code: String, message: String, details: String) throws {
        var status = stat()
        guard fstat(STDIN_FILENO, &status) == 0 else {
            throw CLIError(
                code: "stdin_stat_failed",
                message: "无法检查 stdin 来源。",
                details: String(cString: strerror(errno))
            )
        }

        if (status.st_mode & S_IFMT) == S_IFREG {
            throw CLIError(code: code, message: message, details: details)
        }
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func makeSyllogismTrial(from arguments: [String]) throws -> SyllogismTrial {
        let flags = try FlagParser.parse(arguments)
        let typeValue = try flags.required("type")
        guard let type = SyllogismType(rawValue: typeValue) else {
            throw CLIError(code: "invalid_syllogism_type", message: "未知逻辑题类型：\(typeValue)", details: syllogismImportUsage)
        }

        let trial = SyllogismTrial(
            id: try flags.required("id"),
            premises: flags.all("premise"),
            conclusion: try flags.required("conclusion"),
            isValid: try flags.requiredBool("valid"),
            type: type,
            abstractForm: try flags.required("abstract-form"),
            explanation: try flags.required("explanation"),
            detailedExplanation: try flags.required("detailed-explanation"),
            hasUnverifiedPremise: try flags.bool("unverified-premise", default: false)
        )
        try validateSyllogismTrial(trial)
        return trial
    }

    private static func makeReadingPassage(from arguments: [String]) throws -> ReadingPassage {
        let flags = try FlagParser.parse(arguments)
        let structureValue = try flags.required("structure-type")
        guard let structureType = ReadingStructureType(rawValue: structureValue) else {
            throw CLIError(code: "invalid_structure_type", message: "未知素材结构类型：\(structureValue)", details: passageImportUsage)
        }

        let passage = ReadingPassage(
            id: try flags.required("id"),
            title: try flags.required("title"),
            domainTag: try flags.required("domain-tag"),
            difficulty: try flags.requiredInt("difficulty"),
            structureType: structureType,
            body: try flags.required("body"),
            mainIdeaOptions: flags.all("main-option"),
            mainIdeaAnswerIndex: try flags.requiredInt("answer-index"),
            mainIdeaRubric: MainIdeaRubric(
                idealSummary: try flags.required("ideal-summary"),
                keywords: flags.all("rubric-keyword"),
                trapNote: try flags.required("trap-note")
            ),
            claimAnchors: try flags.all("claim").map(parseClaimAnchor),
            evidenceItems: try flags.all("evidence").map(parseEvidenceItem),
            recallPrompts: try flags.all("recall-prompt").map(parseRecallPrompt),
            recallKeywords: flags.all("recall-keyword"),
            references: try parseReferences(flags.all("reference"))
        )
        try validateReadingPassage(passage)
        return passage
    }

    private static func parseClaimAnchor(_ raw: String) throws -> ReadingClaimAnchor {
        let parts = try splitPipe(raw, expected: 3, label: "claim")
        guard let scope = ReadingClaimAnchor.Scope(rawValue: parts[1]) else {
            throw CLIError(code: "invalid_claim_scope", message: "claim scope 必须是 global 或 local。", details: raw)
        }
        return ReadingClaimAnchor(id: parts[0], text: parts[2], scope: scope)
    }

    private static func parseEvidenceItem(_ raw: String) throws -> EvidenceClassificationItem {
        let parts = try splitPipe(raw, expected: 4, label: "evidence")
        guard let role = EvidenceClassificationItem.Role(rawValue: parts[1]) else {
            throw CLIError(code: "invalid_evidence_role", message: "evidence role 必须是 claim、evidence、background 或 limitation。", details: raw)
        }
        let supportsClaimID = parts[2].isEmpty || parts[2] == "-" ? nil : parts[2]
        return EvidenceClassificationItem(id: parts[0], text: parts[3], role: role, supportsClaimID: supportsClaimID)
    }

    private static func parseRecallPrompt(_ raw: String) throws -> DelayedRecallPrompt {
        let parts = try splitPipe(raw, expected: 3, label: "recall-prompt")
        return DelayedRecallPrompt(id: parts[0], text: parts[2], isTarget: try parseBool(parts[1], label: "recall-prompt isTarget"))
    }

    private static func parseReferences(_ values: [String]) throws -> [MaterialReference]? {
        let references = try values.map { raw -> MaterialReference in
            let parts = try splitPipe(raw, expected: 8, label: "reference")
            guard let year = Int(parts[3]) else {
                throw CLIError(code: "invalid_reference_year", message: "reference year 必须是整数。", details: raw)
            }
            return MaterialReference(
                id: parts[0],
                title: parts[1],
                authors: parts[2].split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) },
                year: year,
                source: parts[4],
                doi: parts[5].isEmpty || parts[5] == "-" ? nil : parts[5],
                url: parts[6].isEmpty || parts[6] == "-" ? nil : parts[6],
                notes: parts[7].isEmpty || parts[7] == "-" ? nil : parts[7]
            )
        }
        return references.isEmpty ? nil : references
    }

    private static func splitPipe(_ raw: String, expected: Int, label: String) throws -> [String] {
        let parts = raw.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        if parts.count != expected {
            let message = "\(label) 格式错误，需要 \(expected) 段，用 | 分隔。"
            throw CLIError(code: "invalid_\(label.replacingOccurrences(of: "-", with: "_"))", message: message, details: raw)
        }
        return parts
    }

    private static func parseBool(_ raw: String, label: String) throws -> Bool {
        switch raw.lowercased() {
        case "true", "yes", "1": return true
        case "false", "no", "0": return false
        default:
            throw CLIError(code: "invalid_bool", message: "\(label) 必须是 true 或 false。", details: raw)
        }
    }

    private static func validateSyllogismTrial(_ trial: SyllogismTrial) throws {
        var issues: [String] = []
        if trial.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("id 不能为空。")
        }
        if trial.premises.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            issues.append("premises 不能包含空字符串。")
        }
        if trial.premises.count < minimumPremiseCount(for: trial.type) {
            issues.append("\(trial.type.rawValue) 至少需要 \(minimumPremiseCount(for: trial.type)) 个前提。")
        }
        if trial.conclusion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("conclusion 不能为空。")
        }
        if trial.abstractForm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("abstractForm 不能为空。")
        }
        if trial.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("explanation 不能为空。")
        }
        if trial.detailedExplanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("detailedExplanation 不能为空。")
        }
        for (label, text) in [
            ("premises", trial.premises.joined(separator: " ")),
            ("conclusion", trial.conclusion),
            ("explanation", trial.explanation),
            ("detailedExplanation", trial.detailedExplanation)
        ] where !containsChinese(in: text) {
            issues.append("\(label) 必须使用中文内容。")
        }
        if !issues.isEmpty {
            throw CLIError(code: "invalid_syllogism", message: issues.joined(separator: "；"), details: syllogismImportUsage)
        }
    }

    private static func validateReadingPassage(_ passage: ReadingPassage) throws {
        var issues: [String] = []
        if passage.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("id 不能为空。") }
        if passage.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("title 不能为空。") }
        if passage.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("body 不能为空。") }
        if passage.mainIdeaOptions.count != 4 { issues.append("main-option 必须正好 4 个。") }
        if !passage.mainIdeaOptions.indices.contains(passage.mainIdeaAnswerIndex) { issues.append("answer-index 必须是 0...3。") }
        if passage.mainIdeaRubric.keywords.count < 5 { issues.append("rubric-keyword 至少需要 5 个。") }
        if passage.claimAnchors.isEmpty { issues.append("claim 至少需要 1 条。") }
        if passage.evidenceItems.count < 4 { issues.append("evidence 至少需要 4 条。") }
        if passage.recallPrompts.count < 5 { issues.append("recall-prompt 至少需要 5 条。") }
        if passage.recallKeywords.count < 5 { issues.append("recall-keyword 至少需要 5 个。") }
        if !(1...3).contains(passage.difficulty) { issues.append("difficulty 必须是 1、2 或 3。") }
        let claimIDs = Set(passage.claimAnchors.map(\.id))
        for item in passage.evidenceItems where item.role == .evidence || item.role == .limitation {
            if let claimID = item.supportsClaimID, !claimIDs.contains(claimID) {
                issues.append("evidence \(item.id) 的 supportsClaimID 指向不存在的 claim。")
            }
        }
        if !issues.isEmpty {
            throw CLIError(code: "invalid_passage", message: issues.joined(separator: "；"), details: passageImportUsage)
        }
    }

    private static func minimumPremiseCount(for type: SyllogismType) -> Int {
        switch type {
        case .constructiveDilemma, .chainReasoning:
            3
        default:
            2
        }
    }

    private static func containsChinese(in text: String) -> Bool {
        text.unicodeScalars.contains { (0x4E00...0x9FFF).contains(Int($0.value)) }
    }

    private static func listPassages(store: CLIStore) throws -> [PassageRow] {
        let approved = try store.loadApprovedReadingPassages().sorted { $0.approvedAt > $1.approvedAt }
        let localIDs = Set(approved.map(\.id))
        return CLIReadingLibrary.all(approved: approved).map { passage in
            PassageRow(
                id: passage.id,
                title: passage.title,
                domainTag: passage.domainTag,
                difficulty: passage.difficulty,
                structureType: passage.structureType.rawValue,
                origin: localIDs.contains(passage.id) ? "local" : "bundled"
            )
        }
    }

    private static func upsertPassage(_ passage: ReadingPassage, store: CLIStore) throws -> ImportResultResponse {
        var approved = try store.loadApprovedReadingPassages()
        let item = ApprovedReadingPassage(
            passage: passage,
            sourceArticle: SourceArticle(
                sourceKind: "local",
                title: passage.title,
                url: "local://\(passage.id)",
                summary: String(passage.body.prefix(200)),
                excerpt: String(passage.body.prefix(500)),
                domainTag: passage.domainTag
            ),
            approvedAt: Date(),
            candidateID: "local-\(passage.id)",
            score: 100
        )
        let action: String
        if let index = approved.firstIndex(where: { $0.id == item.id }) {
            approved[index] = item
            action = "updated"
        } else {
            approved.insert(item, at: 0)
            action = "inserted"
        }
        try store.saveApprovedReadingPassages(approved)
        return ImportResultResponse(
            id: passage.id,
            action: action,
            storagePath: store.storageURL.path,
            premiseCount: nil,
            requiredPremiseCount: nil
        )
    }

    private static func deletePassage(id: String, store: CLIStore) throws -> DeleteResponse {
        var approved = try store.loadApprovedReadingPassages()
        let before = approved.count
        approved.removeAll { $0.id == id }
        guard approved.count != before else {
            return DeleteResponse(id: id, deleted: false, storagePath: store.storageURL.path)
        }
        try store.saveApprovedReadingPassages(approved)
        return DeleteResponse(id: id, deleted: true, storagePath: store.storageURL.path)
    }

    private static func listSyllogisms(store: CLIStore) throws -> [SyllogismRow] {
        try store.loadSyllogismTrials().map { trial in
            SyllogismRow(
                id: trial.id,
                type: trial.type.rawValue,
                isValid: trial.isValid,
                premiseCount: trial.premises.count
            )
        }
    }

    private static func upsertSyllogism(_ trial: SyllogismTrial, store: CLIStore) throws -> ImportResultResponse {
        var trials = try store.loadSyllogismTrials()
        let action: String
        if let index = trials.firstIndex(where: { $0.id == trial.id }) {
            trials[index] = trial
            action = "updated"
        } else {
            trials.insert(trial, at: 0)
            action = "inserted"
        }
        try store.saveSyllogismTrials(trials)
        return ImportResultResponse(
            id: trial.id,
            action: action,
            storagePath: store.storageURL.path,
            premiseCount: trial.premises.count,
            requiredPremiseCount: minimumPremiseCount(for: trial.type)
        )
    }

    private static func deleteSyllogism(id: String, store: CLIStore) throws -> DeleteResponse {
        var trials = try store.loadSyllogismTrials()
        let before = trials.count
        trials.removeAll { $0.id == id }
        guard trials.count != before else {
            return DeleteResponse(id: id, deleted: false, storagePath: store.storageURL.path)
        }
        try store.saveSyllogismTrials(trials)
        return DeleteResponse(id: id, deleted: true, storagePath: store.storageURL.path)
    }

    private static func emitSuccess<T: Encodable>(_ data: T, warnings: [String] = []) {
        let response = CLIResponse(data: data, warnings: warnings, error: nil)
        writeJSON(response)
    }

    private static func emitFailure(code: String, message: String, details: String?) {
        let response = CLIResponse<EmptyData>(
            ok: false,
            data: nil,
            warnings: [],
            error: CLIErrorBody(code: code, message: message, details: details)
        )
        writeJSON(response)
    }

    private static func writeJSON<T: Encodable>(_ value: T) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = (try? encoder.encode(value)) ?? Data(#"{"ok":false,"error":{"code":"encoding_error","message":"无法编码 CLI 输出"}}"#.utf8)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private static let syllogismImportUsage = """
    braindrillctl syllogisms import
      --id trial-id
      --type modusPonens
      --valid true|false
      --premise "中文前提 1"
      --premise "中文前提 2"
      --conclusion "中文结论"
      --abstract-form "P→Q, P ∴ Q"
      --explanation "一句话判定依据"
      --detailed-explanation "说明为什么有效或无效"
      [--unverified-premise true|false]
    """

    private static let passageImportUsage = """
    braindrillctl passages import
      --id passage-id
      --title "标题"
      --domain-tag "领域"
      --difficulty 1|2|3
      --structure-type causeEffect|compareContrast|problemSolution|mechanism
      --body "正文"
      --main-option "选项 1" --main-option "选项 2" --main-option "选项 3" --main-option "选项 4"
      --answer-index 0
      --ideal-summary "理想主旨"
      --rubric-keyword "关键词" ... 至少 5 个
      --trap-note "干扰项说明"
      --claim "id|global|结论锚点文本"
      --evidence "id|evidence|claim-id|证据文本"  至少 4 条；role 只允许 claim/evidence/background/limitation；无支持结论时第三列用 -
      --recall-prompt "id|true|回忆提示文本"  至少 5 条
      --recall-keyword "关键词" ... 至少 5 个
      [--reference "id|title|author1,author2|year|source|doi|url|notes"]

    示例：
    braindrillctl passages import \\
      --id demo-reading-001 \\
      --title "为什么城市树荫能降低热风险" \\
      --domain-tag environment \\
      --difficulty 2 \\
      --structure-type causeEffect \\
      --body "城市树木通过遮挡太阳辐射和蒸腾作用降低局部温度。树荫减少路面和建筑表面的吸热，蒸腾会把一部分热量用于水分蒸发，因此行人感受到的热压力会下降。不过，降温效果还取决于树冠覆盖、通风条件和维护用水，不能简单认为任何树种在任何街道都有相同效果。" \\
      --main-option "树荫能通过遮阴和蒸腾降低热风险，但效果受环境条件影响。" \\
      --main-option "所有树种在所有街道的降温效果完全相同。" \\
      --main-option "树荫只改变视觉感受，不会影响热压力。" \\
      --main-option "只要种树，就不需要考虑城市通风和维护。" \\
      --answer-index 0 \\
      --ideal-summary "城市树木通过遮阴和蒸腾降低局部热压力，但实际效果受树冠、通风和维护条件影响。" \\
      --rubric-keyword 树荫 --rubric-keyword 遮阴 --rubric-keyword 蒸腾 --rubric-keyword 热风险 --rubric-keyword 条件限制 \\
      --trap-note "不要把一般机制误读为所有地点和树种效果完全一致。" \\
      --claim "c1|global|树荫能降低热风险但效果受条件限制。" \\
      --evidence "e1|background|c1|城市树木可以遮挡太阳辐射。" \\
      --evidence "e2|evidence|c1|树荫减少路面和建筑表面的吸热。" \\
      --evidence "e3|evidence|c1|蒸腾会把热量用于水分蒸发。" \\
      --evidence "e4|limitation|c1|降温效果受树冠覆盖、通风和维护用水影响。" \\
      --recall-prompt "r1|true|树荫可以减少表面吸热。" \\
      --recall-prompt "r2|true|蒸腾作用与降温有关。" \\
      --recall-prompt "r3|false|文章认为所有树种降温效果完全相同。" \\
      --recall-prompt "r4|true|通风条件会影响实际降温效果。" \\
      --recall-prompt "r5|false|文章认为种树后不需要维护。" \\
      --recall-keyword 树荫 --recall-keyword 蒸腾 --recall-keyword 遮阴 --recall-keyword 热压力 --recall-keyword 通风 \\
      --reference "ref1|Urban Trees and Heat|Example Author|2026|Example Source|-|https://example.com|示例引用"
    """

    private static let usageText = """
    braindrillctl help
    braindrillctl store path
    braindrillctl passages list
    braindrillctl passages import --id passage-id ...
    braindrillctl passages delete passage-id
    braindrillctl syllogisms list
    braindrillctl syllogisms import --id trial-id ...
    braindrillctl syllogisms delete trial-id
    braindrillctl sqlite path
    braindrillctl sqlite command
    braindrillctl sqlite exec "SELECT COUNT(*) FROM syllogism_trials"

    Import commands:
    \(syllogismImportUsage)

    \(passageImportUsage)

    SQLite ops:
    sqlite path 输出 BrainDrill.sqlite 路径。
    sqlite command 输出可直接使用的 sqlite3 命令。
    sqlite exec 直接对 BrainDrill.sqlite 执行 SQL，支持多条语句和 SELECT 结果回传。
    SQL 应通过命令参数或管道/heredoc 传入；禁止从普通磁盘文件重定向 SQL。

    Syllogism SQLite tables:
    syllogism_trials(id, type, is_valid, difficulty_min, difficulty_max, conclusion,
    abstract_form, explanation, detailed_explanation, has_unverified_premise)
    syllogism_premises(trial_id, position, text)

    ReadingPassage fields:
    id, title, domainTag, difficulty, structureType, body,
    mainIdeaOptions, mainIdeaAnswerIndex, mainIdeaRubric,
    claimAnchors, evidenceItems, recallPrompts, recallKeywords,
    references.

    Required structural rules:
    difficulty must be 1, 2, or 3.
    structureType must be causeEffect, compareContrast, problemSolution, or mechanism.
    mainIdeaOptions must contain exactly 4 options.
    mainIdeaAnswerIndex must be 0...3.
    claimAnchors must contain at least 1 item.
    evidenceItems must contain at least 4 items.
    recallPrompts must contain at least 5 items.
    recallKeywords must contain at least 5 items.
    supportsClaimID, when present, must match a claimAnchors.id.

    Source-quality requirements:
    1. 每条素材必须基于真实可追溯资料，可以来自自然科学、医学、工程、社会科学、人文、法学、经济学等学科。
    2. 内容要严谨、前沿、逻辑清楚；避免绝对化表述，写出边界条件或限制。
    3. 优先使用近 5-10 年综述、系统综述、指南、标准、教材新版、机构报告、官方数据；基础理论可使用经典文献。
    4. references 可选但强烈建议提供，每条包含 id/title/authors/year/source/doi/url/notes；不要编造 DOI、URL、作者、年份。
    5. body 要形成论证链：背景事实 -> 核心机制/因果/比较/问题 -> 证据 -> 限制。
    6. evidenceItems 必须至少 4 条，并尽量覆盖 claim/evidence/background/limitation。
    7. mainIdeaOptions 正好 4 个，mainIdeaAnswerIndex 为 0-3。
    8. recallPrompts 至少 5 条，isTarget=false 是合理但无关的干扰题。
    9. recallKeywords 至少 5 个。
    10. structureType 只能是 causeEffect、compareContrast、problemSolution、mechanism。

    SyllogismTrial fields:
    id, premises, conclusion, isValid, type, abstractForm, explanation,
    detailedExplanation, hasUnverifiedPremise.

    SyllogismTrial structural rules:
    1. 所有题目必须使用中文；premises、conclusion、explanation、detailedExplanation 都应包含中文内容。
    2. 每题至少 2 个前提；constructiveDilemma、chainReasoning 等复合/链式题至少 3 个前提。
    3. contraposition、deMorgan、absorption 等题不能只写成单条等价式转换题，必须加入具体事实，形成完整推理。
    4. 一批导入题应同时包含有效题和无效题，并覆盖条件推理、析取推理、范畴三段论、量词、复合命题、因果谬误。
    5. explanation 用一句话简短说明判定依据；detailedExplanation 说明为什么有效或无效，不能为空。
    6. 导入后必须用 braindrillctl syllogisms list 验证数量和 premiseCount；若 premiseCount 小于要求，先修正再导入。
    conclusion、abstractForm、explanation、detailedExplanation 不能为空。
    type 必须是 help 中可用逻辑类型之一。

    Available syllogism type values:
    modusPonens, modusTollens, affirmConsequent, denyAntecedent,
    disjunctiveSyllogism, disjunctiveFallacy, constructiveDilemma,
    biconditional, biconditionalValid, categoricalValid, categoricalInvalid,
    celarent, darii, ferio, illicitMajor, fourTerms, quantifierTrap,
    universalInstantiation, existentialFallacy, quantifierNegation,
    scopeAmbiguity, chainReasoning, contraposition, deMorgan, absorption,
    correlationCausation, reverseCausation, baseRateNeglect, gamblerFallacy,
    conjunctionFallacy, slipperySlope, falseDilemma, circularReasoning,
    equivocation, hastyGeneralization, compositionDivision.
    """
}

private enum ReadingStructureType: String, Codable, CaseIterable {
    case causeEffect
    case compareContrast
    case problemSolution
    case mechanism
}

private struct MainIdeaRubric: Codable, Equatable {
    let idealSummary: String
    let keywords: [String]
    let trapNote: String
}

private struct ReadingClaimAnchor: Codable, Identifiable, Equatable {
    enum Scope: String, Codable {
        case global
        case local
    }

    let id: String
    let text: String
    let scope: Scope
}

private struct EvidenceClassificationItem: Codable, Identifiable, Equatable {
    enum Role: String, Codable {
        case claim
        case evidence
        case background
        case limitation
    }

    let id: String
    let text: String
    let role: Role
    let supportsClaimID: String?
}

private struct DelayedRecallPrompt: Codable, Identifiable, Equatable {
    let id: String
    let text: String
    let isTarget: Bool
}

private struct MaterialReference: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let authors: [String]
    let year: Int
    let source: String
    let doi: String?
    let url: String?
    let notes: String?
}

private struct ReadingPassage: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let domainTag: String
    let difficulty: Int
    let structureType: ReadingStructureType
    let body: String
    let mainIdeaOptions: [String]
    let mainIdeaAnswerIndex: Int
    let mainIdeaRubric: MainIdeaRubric
    let claimAnchors: [ReadingClaimAnchor]
    let evidenceItems: [EvidenceClassificationItem]
    let recallPrompts: [DelayedRecallPrompt]
    let recallKeywords: [String]
    let references: [MaterialReference]?
}

private enum SyllogismType: String, Codable, CaseIterable {
    case modusPonens
    case modusTollens
    case affirmConsequent
    case denyAntecedent
    case disjunctiveSyllogism
    case disjunctiveFallacy
    case constructiveDilemma
    case biconditional
    case biconditionalValid
    case categoricalValid
    case categoricalInvalid
    case celarent
    case darii
    case ferio
    case illicitMajor
    case fourTerms
    case quantifierTrap
    case universalInstantiation
    case existentialFallacy
    case quantifierNegation
    case scopeAmbiguity
    case chainReasoning
    case contraposition
    case deMorgan
    case absorption
    case correlationCausation
    case reverseCausation
    case baseRateNeglect
    case gamblerFallacy
    case conjunctionFallacy
    case slipperySlope
    case falseDilemma
    case circularReasoning
    case equivocation
    case hastyGeneralization
    case compositionDivision

    var lessonGroup: Int {
        switch self {
        case .modusPonens, .affirmConsequent: return 1
        case .categoricalValid, .categoricalInvalid: return 2
        case .disjunctiveSyllogism, .disjunctiveFallacy: return 3
        case .correlationCausation, .falseDilemma, .hastyGeneralization: return 4
        case .modusTollens, .denyAntecedent, .contraposition: return 5
        case .celarent, .darii, .illicitMajor: return 6
        case .quantifierTrap, .existentialFallacy, .universalInstantiation: return 7
        case .chainReasoning, .biconditional, .biconditionalValid: return 8
        case .reverseCausation, .gamblerFallacy, .slipperySlope: return 9
        case .ferio, .constructiveDilemma, .deMorgan: return 10
        case .quantifierNegation, .scopeAmbiguity, .fourTerms: return 11
        case .baseRateNeglect, .conjunctionFallacy: return 12
        case .circularReasoning, .equivocation, .compositionDivision, .absorption: return 13
        }
    }

    var difficultyRange: ClosedRange<Int> {
        switch lessonGroup {
        case 1...4: 1...3
        case 5...9: 2...3
        case 10...13: 3...3
        default: 1...3
        }
    }
}

private struct SyllogismTrial: Codable, Identifiable, Equatable {
    let id: String
    let premises: [String]
    let conclusion: String
    let isValid: Bool
    let type: SyllogismType
    let abstractForm: String
    let explanation: String
    let detailedExplanation: String
    let hasUnverifiedPremise: Bool

    init(
        id: String,
        premises: [String],
        conclusion: String,
        isValid: Bool,
        type: SyllogismType,
        abstractForm: String,
        explanation: String,
        detailedExplanation: String = "",
        hasUnverifiedPremise: Bool = false
    ) {
        self.id = id
        self.premises = premises
        self.conclusion = conclusion
        self.isValid = isValid
        self.type = type
        self.abstractForm = abstractForm
        self.explanation = explanation
        self.detailedExplanation = detailedExplanation
        self.hasUnverifiedPremise = hasUnverifiedPremise
    }

    enum CodingKeys: String, CodingKey {
        case id
        case premises
        case conclusion
        case isValid
        case type
        case abstractForm
        case explanation
        case detailedExplanation
        case hasUnverifiedPremise
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.premises = try container.decode([String].self, forKey: .premises)
        self.conclusion = try container.decode(String.self, forKey: .conclusion)
        self.isValid = try container.decode(Bool.self, forKey: .isValid)
        self.type = try container.decode(SyllogismType.self, forKey: .type)
        self.abstractForm = try container.decode(String.self, forKey: .abstractForm)
        self.explanation = try container.decode(String.self, forKey: .explanation)
        self.detailedExplanation = try container.decodeIfPresent(String.self, forKey: .detailedExplanation) ?? ""
        self.hasUnverifiedPremise = try container.decodeIfPresent(Bool.self, forKey: .hasUnverifiedPremise) ?? false
    }
}

private struct SourceArticle: Codable, Equatable, Identifiable {
    var id: String
    var sourceKind: String
    var title: String
    var url: String
    var summary: String
    var excerpt: String
    var sourceText: String?
    var publishedAt: Date?
    var fetchedAt: Date
    var author: String?
    var domainTag: String

    init(
        id: String? = nil,
        sourceKind: String,
        title: String,
        url: String,
        summary: String,
        excerpt: String,
        sourceText: String? = nil,
        publishedAt: Date? = nil,
        fetchedAt: Date = Date(),
        author: String? = nil,
        domainTag: String
    ) {
        self.sourceKind = sourceKind
        self.title = title
        self.url = url
        self.summary = summary
        self.excerpt = excerpt
        self.sourceText = sourceText
        self.publishedAt = publishedAt
        self.fetchedAt = fetchedAt
        self.author = author
        self.domainTag = domainTag
        self.id = id ?? StableMaterialID.make(prefix: sourceKind, seed: url)
    }
}

private struct ApprovedReadingPassage: Codable, Equatable, Identifiable {
    var id: String { passage.id }
    var passage: ReadingPassage
    var sourceArticle: SourceArticle
    var approvedAt: Date
    var candidateID: String
    var score: Double
}

private final class CLIStore {
    let storageURL: URL
    private let directoryURL: URL
    private let fileManager: FileManager
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(baseURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let rootURL: URL
        if let baseURL {
            rootURL = baseURL
        } else if let cloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true) {
            rootURL = cloudURL
        } else {
            rootURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
        }
        self.directoryURL = rootURL.appendingPathComponent("BrainDrill", isDirectory: true)
        self.storageURL = directoryURL.appendingPathComponent("BrainDrill.sqlite")
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? bootstrap()
    }

    static func live() -> CLIStore {
        CLIStore()
    }

    func loadApprovedReadingPassages() throws -> [ApprovedReadingPassage] {
        try withStatement(
            """
            SELECT id, title, domain_tag, difficulty, structure_type, body,
                   main_idea_answer_index, ideal_summary, rubric_trap_note,
                   source_id, source_kind, source_title, source_url, source_summary,
                   source_excerpt, source_text, source_published_at, source_fetched_at,
                   source_author, source_domain_tag, approved_at, candidate_id, score
            FROM reading_passages
            ORDER BY approved_at DESC
            """
        ) { statement in
            var passages: [ApprovedReadingPassage] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                let passageID = columnString(statement, 0)
                guard let structureType = ReadingStructureType(rawValue: columnString(statement, 4)) else { continue }
                let passage = ReadingPassage(
                    id: passageID,
                    title: columnString(statement, 1),
                    domainTag: columnString(statement, 2),
                    difficulty: Int(sqlite3_column_int(statement, 3)),
                    structureType: structureType,
                    body: columnString(statement, 5),
                    mainIdeaOptions: try loadOrderedStrings("SELECT text FROM reading_main_idea_options WHERE passage_id = ? ORDER BY position", id: passageID),
                    mainIdeaAnswerIndex: Int(sqlite3_column_int(statement, 6)),
                    mainIdeaRubric: MainIdeaRubric(
                        idealSummary: columnString(statement, 7),
                        keywords: try loadOrderedStrings("SELECT keyword FROM reading_rubric_keywords WHERE passage_id = ? ORDER BY position", id: passageID),
                        trapNote: columnString(statement, 8)
                    ),
                    claimAnchors: try loadClaimAnchors(passageID: passageID),
                    evidenceItems: try loadEvidenceItems(passageID: passageID),
                    recallPrompts: try loadRecallPrompts(passageID: passageID),
                    recallKeywords: try loadOrderedStrings("SELECT keyword FROM reading_recall_keywords WHERE passage_id = ? ORDER BY position", id: passageID),
                    references: try loadReferences(passageID: passageID)
                )
                let article = SourceArticle(
                    id: columnString(statement, 9),
                    sourceKind: columnString(statement, 10),
                    title: columnString(statement, 11),
                    url: columnString(statement, 12),
                    summary: columnString(statement, 13),
                    excerpt: columnString(statement, 14),
                    sourceText: columnOptionalString(statement, 15),
                    publishedAt: parseDate(columnOptionalString(statement, 16)),
                    fetchedAt: parseDate(columnOptionalString(statement, 17)) ?? Date(),
                    author: columnOptionalString(statement, 18),
                    domainTag: columnString(statement, 19)
                )
                passages.append(ApprovedReadingPassage(
                    passage: passage,
                    sourceArticle: article,
                    approvedAt: parseDate(columnOptionalString(statement, 20)) ?? Date(),
                    candidateID: columnString(statement, 21),
                    score: sqlite3_column_double(statement, 22)
                ))
            }
            return passages
        }
    }

    func saveApprovedReadingPassages(_ passages: [ApprovedReadingPassage]) throws {
        try clearReadingTables()
        for passage in passages {
            try saveApprovedReadingPassage(passage)
        }
    }

    private func clearReadingTables() throws {
        for table in [
            "reading_references",
            "reading_recall_keywords",
            "reading_recall_prompts",
            "reading_evidence_items",
            "reading_claim_anchors",
            "reading_rubric_keywords",
            "reading_main_idea_options",
            "reading_passages"
        ] {
            try execute("DELETE FROM \(table)")
        }
    }

    private func saveApprovedReadingPassage(_ passage: ApprovedReadingPassage) throws {
        try execute(
            """
            INSERT OR REPLACE INTO reading_passages
            (id, title, domain_tag, difficulty, structure_type, body,
             main_idea_answer_index, ideal_summary, rubric_trap_note,
             source_id, source_kind, source_title, source_url, source_summary,
             source_excerpt, source_text, source_published_at, source_fetched_at,
             source_author, source_domain_tag, approved_at, candidate_id, score)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(passage.id),
                .text(passage.passage.title),
                .text(passage.passage.domainTag),
                .int(passage.passage.difficulty),
                .text(passage.passage.structureType.rawValue),
                .text(passage.passage.body),
                .int(passage.passage.mainIdeaAnswerIndex),
                .text(passage.passage.mainIdeaRubric.idealSummary),
                .text(passage.passage.mainIdeaRubric.trapNote),
                .text(passage.sourceArticle.id),
                .text(passage.sourceArticle.sourceKind),
                .text(passage.sourceArticle.title),
                .text(passage.sourceArticle.url),
                .text(passage.sourceArticle.summary),
                .text(passage.sourceArticle.excerpt),
                .optionalText(passage.sourceArticle.sourceText),
                .optionalText(passage.sourceArticle.publishedAt.map(isoString)),
                .text(isoString(passage.sourceArticle.fetchedAt)),
                .optionalText(passage.sourceArticle.author),
                .text(passage.sourceArticle.domainTag),
                .text(isoString(passage.approvedAt)),
                .text(passage.candidateID),
                .double(passage.score)
            ]
        )
        for (index, option) in passage.passage.mainIdeaOptions.enumerated() {
            try execute("INSERT INTO reading_main_idea_options (passage_id, position, text) VALUES (?, ?, ?)", bindings: [.text(passage.id), .int(index), .text(option)])
        }
        for (index, keyword) in passage.passage.mainIdeaRubric.keywords.enumerated() {
            try execute("INSERT INTO reading_rubric_keywords (passage_id, position, keyword) VALUES (?, ?, ?)", bindings: [.text(passage.id), .int(index), .text(keyword)])
        }
        for claim in passage.passage.claimAnchors {
            try execute("INSERT INTO reading_claim_anchors (passage_id, id, text, scope) VALUES (?, ?, ?, ?)", bindings: [.text(passage.id), .text(claim.id), .text(claim.text), .text(claim.scope.rawValue)])
        }
        for item in passage.passage.evidenceItems {
            try execute("INSERT INTO reading_evidence_items (passage_id, id, text, role, supports_claim_id) VALUES (?, ?, ?, ?, ?)", bindings: [.text(passage.id), .text(item.id), .text(item.text), .text(item.role.rawValue), .optionalText(item.supportsClaimID)])
        }
        for prompt in passage.passage.recallPrompts {
            try execute("INSERT INTO reading_recall_prompts (passage_id, id, text, is_target) VALUES (?, ?, ?, ?)", bindings: [.text(passage.id), .text(prompt.id), .text(prompt.text), .int(prompt.isTarget ? 1 : 0)])
        }
        for (index, keyword) in passage.passage.recallKeywords.enumerated() {
            try execute("INSERT INTO reading_recall_keywords (passage_id, position, keyword) VALUES (?, ?, ?)", bindings: [.text(passage.id), .int(index), .text(keyword)])
        }
        for reference in passage.passage.references ?? [] {
            try execute(
                """
                INSERT INTO reading_references
                (passage_id, id, title, authors, year, source, doi, url, notes)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                bindings: [
                    .text(passage.id),
                    .text(reference.id),
                    .text(reference.title),
                    .text(reference.authors.joined(separator: "\u{1F}")),
                    .int(reference.year),
                    .text(reference.source),
                    .optionalText(reference.doi),
                    .optionalText(reference.url),
                    .optionalText(reference.notes)
                ]
            )
        }
    }

    func loadSyllogismTrials() throws -> [SyllogismTrial] {
        try withStatement(
            """
            SELECT id, type, is_valid, conclusion, abstract_form, explanation,
                   detailed_explanation, has_unverified_premise
            FROM syllogism_trials
            ORDER BY id
            """
        ) { statement in
            var trials: [SyllogismTrial] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = columnString(statement, 0)
                guard let type = SyllogismType(rawValue: columnString(statement, 1)) else { continue }
                trials.append(SyllogismTrial(
                    id: id,
                    premises: try loadOrderedStrings("SELECT text FROM syllogism_premises WHERE trial_id = ? ORDER BY position", id: id),
                    conclusion: columnString(statement, 3),
                    isValid: sqlite3_column_int(statement, 2) == 1,
                    type: type,
                    abstractForm: columnString(statement, 4),
                    explanation: columnString(statement, 5),
                    detailedExplanation: columnString(statement, 6),
                    hasUnverifiedPremise: sqlite3_column_int(statement, 7) == 1
                ))
            }
            return trials
        }
    }

    func saveSyllogismTrials(_ trials: [SyllogismTrial]) throws {
        try execute("DELETE FROM syllogism_premises")
        try execute("DELETE FROM syllogism_trials")
        for trial in trials {
            try execute(
                """
                INSERT OR REPLACE INTO syllogism_trials
                (id, type, is_valid, difficulty_min, difficulty_max, conclusion,
                 abstract_form, explanation, detailed_explanation, has_unverified_premise)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                bindings: [
                    .text(trial.id),
                    .text(trial.type.rawValue),
                    .int(trial.isValid ? 1 : 0),
                    .int(trial.type.difficultyRange.lowerBound),
                    .int(trial.type.difficultyRange.upperBound),
                    .text(trial.conclusion),
                    .text(trial.abstractForm),
                    .text(trial.explanation),
                    .text(trial.detailedExplanation),
                    .int(trial.hasUnverifiedPremise ? 1 : 0)
                ]
            )
            for (index, premise) in trial.premises.enumerated() {
                try execute("INSERT INTO syllogism_premises (trial_id, position, text) VALUES (?, ?, ?)", bindings: [.text(trial.id), .int(index), .text(premise)])
            }
        }
    }

    private func bootstrap() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try execute("PRAGMA journal_mode = WAL")
        try execute(
            """
            CREATE TABLE IF NOT EXISTS reading_passages (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                domain_tag TEXT NOT NULL,
                difficulty INTEGER NOT NULL,
                structure_type TEXT NOT NULL,
                body TEXT NOT NULL,
                main_idea_answer_index INTEGER NOT NULL,
                ideal_summary TEXT NOT NULL,
                rubric_trap_note TEXT NOT NULL,
                source_id TEXT NOT NULL,
                source_kind TEXT NOT NULL,
                source_title TEXT NOT NULL,
                source_url TEXT NOT NULL,
                source_summary TEXT NOT NULL,
                source_excerpt TEXT NOT NULL,
                source_text TEXT,
                source_published_at TEXT,
                source_fetched_at TEXT NOT NULL,
                source_author TEXT,
                source_domain_tag TEXT NOT NULL,
                approved_at TEXT NOT NULL,
                candidate_id TEXT NOT NULL,
                score REAL NOT NULL
            )
            """
        )
        try execute("CREATE INDEX IF NOT EXISTS idx_reading_passages_domain ON reading_passages(domain_tag, difficulty)")
        try execute("CREATE TABLE IF NOT EXISTS reading_main_idea_options (passage_id TEXT NOT NULL, position INTEGER NOT NULL, text TEXT NOT NULL, PRIMARY KEY (passage_id, position), FOREIGN KEY (passage_id) REFERENCES reading_passages(id) ON DELETE CASCADE)")
        try execute("CREATE TABLE IF NOT EXISTS reading_rubric_keywords (passage_id TEXT NOT NULL, position INTEGER NOT NULL, keyword TEXT NOT NULL, PRIMARY KEY (passage_id, position), FOREIGN KEY (passage_id) REFERENCES reading_passages(id) ON DELETE CASCADE)")
        try execute("CREATE TABLE IF NOT EXISTS reading_claim_anchors (passage_id TEXT NOT NULL, id TEXT NOT NULL, text TEXT NOT NULL, scope TEXT NOT NULL, PRIMARY KEY (passage_id, id), FOREIGN KEY (passage_id) REFERENCES reading_passages(id) ON DELETE CASCADE)")
        try execute("CREATE TABLE IF NOT EXISTS reading_evidence_items (passage_id TEXT NOT NULL, id TEXT NOT NULL, text TEXT NOT NULL, role TEXT NOT NULL, supports_claim_id TEXT, PRIMARY KEY (passage_id, id), FOREIGN KEY (passage_id) REFERENCES reading_passages(id) ON DELETE CASCADE)")
        try execute("CREATE TABLE IF NOT EXISTS reading_recall_prompts (passage_id TEXT NOT NULL, id TEXT NOT NULL, text TEXT NOT NULL, is_target INTEGER NOT NULL, PRIMARY KEY (passage_id, id), FOREIGN KEY (passage_id) REFERENCES reading_passages(id) ON DELETE CASCADE)")
        try execute("CREATE TABLE IF NOT EXISTS reading_recall_keywords (passage_id TEXT NOT NULL, position INTEGER NOT NULL, keyword TEXT NOT NULL, PRIMARY KEY (passage_id, position), FOREIGN KEY (passage_id) REFERENCES reading_passages(id) ON DELETE CASCADE)")
        try execute("CREATE TABLE IF NOT EXISTS reading_references (passage_id TEXT NOT NULL, id TEXT NOT NULL, title TEXT NOT NULL, authors TEXT NOT NULL, year INTEGER NOT NULL, source TEXT NOT NULL, doi TEXT, url TEXT, notes TEXT, PRIMARY KEY (passage_id, id), FOREIGN KEY (passage_id) REFERENCES reading_passages(id) ON DELETE CASCADE)")
        try execute(
            """
            CREATE TABLE IF NOT EXISTS syllogism_trials (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                is_valid INTEGER NOT NULL,
                difficulty_min INTEGER NOT NULL,
                difficulty_max INTEGER NOT NULL,
                conclusion TEXT NOT NULL,
                abstract_form TEXT NOT NULL,
                explanation TEXT NOT NULL,
                detailed_explanation TEXT NOT NULL,
                has_unverified_premise INTEGER NOT NULL
            )
            """
        )
        try execute("CREATE INDEX IF NOT EXISTS idx_syllogism_trials_type ON syllogism_trials(type, is_valid)")
        try execute("CREATE TABLE IF NOT EXISTS syllogism_premises (trial_id TEXT NOT NULL, position INTEGER NOT NULL, text TEXT NOT NULL, PRIMARY KEY (trial_id, position), FOREIGN KEY (trial_id) REFERENCES syllogism_trials(id) ON DELETE CASCADE)")
        try migrateLegacyJSONIfNeeded()
    }

    private func migrateLegacyJSONIfNeeded() throws {
        if try tableIsEmpty("reading_passages") {
            let url = directoryURL.appendingPathComponent("approved-reading-passages.json")
            if fileManager.fileExists(atPath: url.path),
               let passages = try? decoder.decode([ApprovedReadingPassage].self, from: Data(contentsOf: url)) {
                try saveApprovedReadingPassages(passages)
            }
        }
    }

    private func tableIsEmpty(_ table: String) throws -> Bool {
        try withStatement("SELECT COUNT(*) FROM \(table)") { statement in
            guard sqlite3_step(statement) == SQLITE_ROW else { return true }
            return sqlite3_column_int64(statement, 0) == 0
        }
    }

    func executeSQL(_ sql: String) throws -> SQLiteExecResponse {
        var database: OpaquePointer?
        guard sqlite3_open(storageURL.path, &database) == SQLITE_OK else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(database)
            throw CLIError(code: "sqlite_open_failed", message: message, details: storageURL.path)
        }
        sqlite3_busy_timeout(database, 5000)
        defer { sqlite3_close(database) }

        let collector = SQLiteRowCollector()
        let context = Unmanaged.passUnretained(collector).toOpaque()
        let beforeChanges = sqlite3_total_changes(database)
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(database, sql, sqliteExecCollectRows, context, &errorMessage)
        if result != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(database))
            sqlite3_free(errorMessage)
            throw CLIError(code: "sqlite_exec_failed", message: message, details: sql)
        }
        let changes = Int(sqlite3_total_changes(database) - beforeChanges)
        return SQLiteExecResponse(
            changes: changes,
            rowCount: collector.rows.count,
            rows: collector.rows,
            storagePath: storageURL.path
        )
    }

    private func loadOrderedStrings(_ sql: String, id: String) throws -> [String] {
        try withStatement(sql, bindings: [.text(id)]) { statement in
            var values: [String] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                values.append(columnString(statement, 0))
            }
            return values
        }
    }

    private func loadClaimAnchors(passageID: String) throws -> [ReadingClaimAnchor] {
        try withStatement("SELECT id, text, scope FROM reading_claim_anchors WHERE passage_id = ? ORDER BY rowid", bindings: [.text(passageID)]) { statement in
            var values: [ReadingClaimAnchor] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let scope = ReadingClaimAnchor.Scope(rawValue: columnString(statement, 2)) else { continue }
                values.append(ReadingClaimAnchor(id: columnString(statement, 0), text: columnString(statement, 1), scope: scope))
            }
            return values
        }
    }

    private func loadEvidenceItems(passageID: String) throws -> [EvidenceClassificationItem] {
        try withStatement("SELECT id, text, role, supports_claim_id FROM reading_evidence_items WHERE passage_id = ? ORDER BY rowid", bindings: [.text(passageID)]) { statement in
            var values: [EvidenceClassificationItem] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let role = EvidenceClassificationItem.Role(rawValue: columnString(statement, 2)) else { continue }
                values.append(EvidenceClassificationItem(id: columnString(statement, 0), text: columnString(statement, 1), role: role, supportsClaimID: columnOptionalString(statement, 3)))
            }
            return values
        }
    }

    private func loadRecallPrompts(passageID: String) throws -> [DelayedRecallPrompt] {
        try withStatement("SELECT id, text, is_target FROM reading_recall_prompts WHERE passage_id = ? ORDER BY rowid", bindings: [.text(passageID)]) { statement in
            var values: [DelayedRecallPrompt] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                values.append(DelayedRecallPrompt(id: columnString(statement, 0), text: columnString(statement, 1), isTarget: sqlite3_column_int(statement, 2) == 1))
            }
            return values
        }
    }

    private func loadReferences(passageID: String) throws -> [MaterialReference]? {
        let references: [MaterialReference] = try withStatement(
            "SELECT id, title, authors, year, source, doi, url, notes FROM reading_references WHERE passage_id = ? ORDER BY rowid",
            bindings: [.text(passageID)]
        ) { statement in
            var values: [MaterialReference] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                values.append(MaterialReference(
                    id: columnString(statement, 0),
                    title: columnString(statement, 1),
                    authors: columnString(statement, 2).split(separator: "\u{1F}").map(String.init),
                    year: Int(sqlite3_column_int(statement, 3)),
                    source: columnString(statement, 4),
                    doi: columnOptionalString(statement, 5),
                    url: columnOptionalString(statement, 6),
                    notes: columnOptionalString(statement, 7)
                ))
            }
            return values
        }
        return references.isEmpty ? nil : references
    }

    private enum Binding {
        case text(String)
        case optionalText(String?)
        case int(Int)
        case double(Double)
        case data(Data)
    }

    private func execute(_ sql: String, bindings: [Binding] = []) throws {
        try withStatement(sql, bindings: bindings) { statement in
            let result = sqlite3_step(statement)
            guard result == SQLITE_DONE || result == SQLITE_ROW else {
                throw CLIError(code: "sqlite_step_failed", message: lastSQLiteError(statement: statement), details: sql)
            }
        }
    }

    private func withStatement<T>(_ sql: String, bindings: [Binding] = [], _ operation: (OpaquePointer?) throws -> T) throws -> T {
        var database: OpaquePointer?
        guard sqlite3_open(storageURL.path, &database) == SQLITE_OK else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(database)
            throw CLIError(code: "sqlite_open_failed", message: message, details: storageURL.path)
        }
        sqlite3_busy_timeout(database, 5000)
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(database))
            sqlite3_finalize(statement)
            throw CLIError(code: "sqlite_prepare_failed", message: message, details: sql)
        }
        defer { sqlite3_finalize(statement) }

        for (index, binding) in bindings.enumerated() {
            try bind(binding, at: Int32(index + 1), statement: statement)
        }

        return try operation(statement)
    }

    private func bind(_ binding: Binding, at index: Int32, statement: OpaquePointer?) throws {
        let result: Int32
        switch binding {
        case let .text(value):
            result = sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
        case let .optionalText(value):
            if let value {
                result = sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
            } else {
                result = sqlite3_bind_null(statement, index)
            }
        case let .int(value):
            result = sqlite3_bind_int64(statement, index, sqlite3_int64(value))
        case let .double(value):
            result = sqlite3_bind_double(statement, index, value)
        case let .data(value):
            result = value.withUnsafeBytes { buffer in
                sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(value.count), sqliteTransient)
            }
        }
        guard result == SQLITE_OK else {
            throw CLIError(code: "sqlite_bind_failed", message: lastSQLiteError(statement: statement), details: nil)
        }
    }

    private func columnData(_ statement: OpaquePointer?, _ index: Int32) -> Data? {
        guard let bytes = sqlite3_column_blob(statement, index) else { return nil }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, index)))
    }

    private func columnString(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: text)
    }

    private func columnOptionalString(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return columnString(statement, index)
    }

    private func isoString(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }

    private func lastSQLiteError(statement: OpaquePointer?) -> String {
        guard let database = statement.flatMap({ sqlite3_db_handle($0) }) else { return "unknown" }
        return String(cString: sqlite3_errmsg(database))
    }

    private var sqliteTransient: sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }
}

private enum CLIReadingLibrary {
    static func all(approved: [ApprovedReadingPassage]) -> [ReadingPassage] {
        var combined = Dictionary(uniqueKeysWithValues: bundled().map { ($0.id, $0) })
        for item in approved {
            combined[item.passage.id] = item.passage
        }
        return combined.values.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }

    private static func bundled() -> [ReadingPassage] {
        guard let url = locateResource(named: "reading_passages", extension: "json"),
              let data = try? Data(contentsOf: url),
              let passages = try? JSONDecoder().decode([ReadingPassage].self, from: data) else {
            return []
        }
        return passages
    }

    private static func locateResource(named name: String, extension ext: String) -> URL? {
        let fileName = "\(name).\(ext)"
        let bundles = [Bundle.main] + Bundle.allBundles + Bundle.allFrameworks
        for bundle in bundles {
            if let direct = bundle.url(forResource: name, withExtension: ext) {
                return direct
            }
            if let nested = bundle.url(forResource: name, withExtension: ext, subdirectory: "Reading") {
                return nested
            }
            if let nested = bundle.url(forResource: name, withExtension: ext, subdirectory: "Resources/Reading") {
                return nested
            }
        }

        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let candidates = [
            currentDirectory.appendingPathComponent("Resources/Reading/\(fileName)"),
            currentDirectory.appendingPathComponent("Reading/\(fileName)"),
            currentDirectory.appendingPathComponent(fileName)
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}

private enum StableMaterialID {
    static func make(prefix: String, seed: String) -> String {
        let normalized = seed.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in normalized.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return "\(prefix)-\(String(hash, radix: 16))"
    }
}

private struct FlagParser {
    private var values: [String: [String]]

    static func parse(_ arguments: [String]) throws -> FlagParser {
        var values: [String: [String]] = [:]
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            guard argument.hasPrefix("--") else {
                throw CLIError(code: "unexpected_argument", message: "未知参数：\(argument)", details: nil)
            }

            let key: String
            let value: String
            if let separator = argument.firstIndex(of: "=") {
                key = String(argument[argument.index(argument.startIndex, offsetBy: 2)..<separator])
                value = String(argument[argument.index(after: separator)...])
            } else {
                key = String(argument.dropFirst(2))
                let valueIndex = index + 1
                guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--") else {
                    throw CLIError(code: "missing_flag_value", message: "缺少参数值：--\(key)", details: nil)
                }
                value = arguments[valueIndex]
                index += 1
            }
            values[key, default: []].append(value)
            index += 1
        }
        return FlagParser(values: values)
    }

    func required(_ key: String) throws -> String {
        guard let value = values[key]?.last, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CLIError(code: "missing_required_flag", message: "缺少必填参数：--\(key)", details: nil)
        }
        return value
    }

    func all(_ key: String) -> [String] {
        values[key] ?? []
    }

    func requiredInt(_ key: String) throws -> Int {
        let value = try required(key)
        guard let intValue = Int(value) else {
            throw CLIError(code: "invalid_int", message: "--\(key) 必须是整数。", details: value)
        }
        return intValue
    }

    func requiredBool(_ key: String) throws -> Bool {
        try bool(key, required: true, default: false)
    }

    func bool(_ key: String, default defaultValue: Bool) throws -> Bool {
        try bool(key, required: false, default: defaultValue)
    }

    private func bool(_ key: String, required: Bool, default defaultValue: Bool) throws -> Bool {
        guard let value = values[key]?.last else {
            if required {
                throw CLIError(code: "missing_required_flag", message: "缺少必填参数：--\(key)", details: nil)
            }
            return defaultValue
        }
        switch value.lowercased() {
        case "true", "yes", "1": return true
        case "false", "no", "0": return false
        default:
            throw CLIError(code: "invalid_bool", message: "--\(key) 必须是 true 或 false。", details: value)
        }
    }
}

private final class SQLiteRowCollector {
    var rows: [[String: String?]] = []
}

private nonisolated(unsafe) let sqliteExecCollectRows: @convention(c) (
    UnsafeMutableRawPointer?,
    Int32,
    UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?,
    UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 = { context, columnCount, values, columnNames in
    guard let context else { return 1 }
    let collector = Unmanaged<SQLiteRowCollector>.fromOpaque(context).takeUnretainedValue()
    var row: [String: String?] = [:]
    for index in 0..<Int(columnCount) {
        let name = columnNames?[index].map { String(cString: $0) } ?? "column_\(index)"
        let value = values?[index].map { String(cString: $0) }
        row[name] = value
    }
    collector.rows.append(row)
    return 0
}

private struct CLIResponse<T: Encodable>: Encodable {
    var ok: Bool = true
    var data: T?
    var warnings: [String]
    var error: CLIErrorBody?
}

private struct CLIErrorBody: Encodable {
    var code: String
    var message: String
    var details: String?
}

private struct CLIError: Error {
    var code: String
    var message: String
    var details: String?
}

private struct EmptyData: Encodable {}

private struct HelpResponse: Encodable {
    var usage: String
}

private struct StorePathResponse: Encodable {
    var path: String
}

private struct SQLiteCommandResponse: Encodable {
    var command: String
}

private struct SQLiteExecResponse: Encodable {
    var changes: Int
    var rowCount: Int
    var rows: [[String: String?]]
    var storagePath: String
}

private struct PassageListResponse: Encodable {
    var count: Int
    var passages: [PassageRow]
}

private struct PassageRow: Encodable {
    var id: String
    var title: String
    var domainTag: String
    var difficulty: Int
    var structureType: String
    var origin: String
}

private struct SyllogismListResponse: Encodable {
    var count: Int
    var syllogisms: [SyllogismRow]
}

private struct SyllogismRow: Encodable {
    var id: String
    var type: String
    var isValid: Bool
    var premiseCount: Int
}

private struct ImportResultResponse: Encodable {
    var id: String
    var action: String
    var storagePath: String
    var premiseCount: Int?
    var requiredPremiseCount: Int?
}

private struct DeleteResponse: Encodable {
    var id: String
    var deleted: Bool
    var storagePath: String
}

BrainDrillCLI.main()
