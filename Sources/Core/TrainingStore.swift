import Foundation
import SQLite3

protocol TrainingStore {
    var storageURL: URL { get }
    func loadSessions() throws -> [SessionResult]
    func saveSessions(_ sessions: [SessionResult]) throws
    func loadSettings() throws -> TrainingSettings
    func saveSettings(_ settings: TrainingSettings) throws
    func loadAdaptiveStates() throws -> [TrainingModule: ModuleAdaptiveState]
    func saveAdaptiveStates(_ states: [TrainingModule: ModuleAdaptiveState]) throws
    func loadApprovedReadingPassages() throws -> [ApprovedReadingPassage]
    func saveApprovedReadingPassages(_ passages: [ApprovedReadingPassage]) throws
    func loadApprovedSyllogismTrials() throws -> [SyllogismTrial]
    func saveApprovedSyllogismTrials(_ trials: [SyllogismTrial]) throws
    func loadApprovedBankQuestions() throws -> [BankQuestion]
    func saveApprovedBankQuestions(_ questions: [BankQuestion]) throws
    func loadStreakTracker() throws -> StreakTracker?
    func saveStreakTracker(_ tracker: StreakTracker) throws
    func loadAchievementTracker() throws -> AchievementTracker?
    func saveAchievementTracker(_ tracker: AchievementTracker) throws
}

enum TrainingStoreError: LocalizedError {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case bindFailed(String)

    var errorDescription: String? {
        switch self {
        case let .openFailed(message): "SQLite 打开失败：\(message)"
        case let .prepareFailed(message): "SQLite 准备语句失败：\(message)"
        case let .stepFailed(message): "SQLite 执行失败：\(message)"
        case let .bindFailed(message): "SQLite 绑定参数失败：\(message)"
        }
    }
}

final class LocalTrainingStore: TrainingStore {
    private struct PersistedStateV2: Codable {
        var version: Int = 2
        var sessions: [SessionResult] = []
        var settings: TrainingSettings = .default
        var adaptiveStates: [String: ModuleAdaptiveState] = [:]
    }

    private struct LegacyState: Codable {
        var results: [SchulteSessionResult]?
        var settings: LegacySettings?

        struct LegacySettings: Codable {
            var showHints: Bool
            var preferredDifficulty: SchulteDifficulty
            var adaptiveDifficultyEnabled: Bool
            var adaptiveConfig: AdaptiveDifficulty.Config
        }
    }

    let storageURL: URL
    private let directoryURL: URL
    private let legacyJSONURL: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

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
        self.legacyJSONURL = directoryURL.appendingPathComponent("training-data.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601

        try? bootstrap()
    }

    static func live() -> LocalTrainingStore {
        LocalTrainingStore()
    }

    func loadSessions() throws -> [SessionResult] {
        // Legacy rows for removed modules are dropped once by `migrateSchemaIfNeeded`,
        // so no query-time module filtering is needed here.
        try fetchRows(
            "SELECT json FROM sessions ORDER BY ended_at DESC",
            decode: SessionResult.self
        )
    }

    func saveSessions(_ sessions: [SessionResult]) throws {
        try replaceRows(table: "sessions") {
            for session in sessions {
                try execute(
                    """
                    INSERT OR REPLACE INTO sessions (id, module, started_at, ended_at, json)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    bindings: [
                        .text(session.id.uuidString),
                        .text(session.module.rawValue),
                        .text(isoString(session.startedAt)),
                        .text(isoString(session.endedAt)),
                        .data(try encoder.encode(session))
                    ]
                )
            }
        }
    }

    func loadSettings() throws -> TrainingSettings {
        let loaded = try fetchSingleDocument(TrainingSettings.self, sql: "SELECT json FROM settings WHERE id = 1")
            ?? .default
        let normalized = loaded.normalizedForCurrentDefaults()
        if normalized != loaded {
            try saveSettings(normalized)
        }
        return normalized
    }

    func saveSettings(_ settings: TrainingSettings) throws {
        try execute(
            """
            INSERT OR REPLACE INTO settings (id, json)
            VALUES (1, ?)
            """,
            bindings: [.data(try encoder.encode(settings))]
        )
    }

    func loadAdaptiveStates() throws -> [TrainingModule: ModuleAdaptiveState] {
        try withStatement("SELECT module, json FROM adaptive_states") { statement in
            var states: [TrainingModule: ModuleAdaptiveState] = [:]
            while sqlite3_step(statement) == SQLITE_ROW {
                guard
                    let moduleText = sqlite3_column_text(statement, 0),
                    let module = TrainingModule(rawValue: String(cString: moduleText)),
                    let data = columnData(statement, 1)
                else { continue }
                states[module] = try decoder.decode(ModuleAdaptiveState.self, from: data)
            }
            return states
        }
    }

    func saveAdaptiveStates(_ states: [TrainingModule: ModuleAdaptiveState]) throws {
        try replaceRows(table: "adaptive_states") {
            for (module, state) in states {
                try execute(
                    "INSERT OR REPLACE INTO adaptive_states (module, json) VALUES (?, ?)",
                    bindings: [
                        .text(module.rawValue),
                        .data(try encoder.encode(state))
                    ]
                )
            }
        }
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
                guard
                    let structureType = ReadingStructureType(rawValue: columnString(statement, 4)),
                    let sourceKind = ConcreteSourceKind(rawValue: columnString(statement, 10))
                else { continue }

                let passage = ReadingPassage(
                    id: passageID,
                    title: columnString(statement, 1),
                    domainTag: columnString(statement, 2),
                    difficulty: Int(sqlite3_column_int(statement, 3)),
                    structureType: structureType,
                    body: columnString(statement, 5),
                    mainIdeaOptions: try loadMainIdeaOptions(passageID: passageID),
                    mainIdeaAnswerIndex: Int(sqlite3_column_int(statement, 6)),
                    mainIdeaRubric: MainIdeaRubric(
                        idealSummary: columnString(statement, 7),
                        keywords: try loadRubricKeywords(passageID: passageID),
                        trapNote: columnString(statement, 8)
                    ),
                    claimAnchors: try loadClaimAnchors(passageID: passageID),
                    evidenceItems: try loadEvidenceItems(passageID: passageID),
                    recallPrompts: try loadRecallPrompts(passageID: passageID),
                    recallKeywords: try loadRecallKeywords(passageID: passageID),
                    references: try loadReferences(passageID: passageID)
                )

                let sourceArticle = SourceArticle(
                    id: columnString(statement, 9),
                    sourceKind: sourceKind,
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
                    sourceArticle: sourceArticle,
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
                .text(passage.sourceArticle.sourceKind.rawValue),
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
            try execute(
                "INSERT INTO reading_main_idea_options (passage_id, position, text) VALUES (?, ?, ?)",
                bindings: [.text(passage.id), .int(index), .text(option)]
            )
        }
        for (index, keyword) in passage.passage.mainIdeaRubric.keywords.enumerated() {
            try execute(
                "INSERT INTO reading_rubric_keywords (passage_id, position, keyword) VALUES (?, ?, ?)",
                bindings: [.text(passage.id), .int(index), .text(keyword)]
            )
        }
        for claim in passage.passage.claimAnchors {
            try execute(
                "INSERT INTO reading_claim_anchors (passage_id, id, text, scope) VALUES (?, ?, ?, ?)",
                bindings: [.text(passage.id), .text(claim.id), .text(claim.text), .text(claim.scope.rawValue)]
            )
        }
        for item in passage.passage.evidenceItems {
            try execute(
                "INSERT INTO reading_evidence_items (passage_id, id, text, role, supports_claim_id) VALUES (?, ?, ?, ?, ?)",
                bindings: [.text(passage.id), .text(item.id), .text(item.text), .text(item.role.rawValue), .optionalText(item.supportsClaimID)]
            )
        }
        for prompt in passage.passage.recallPrompts {
            try execute(
                "INSERT INTO reading_recall_prompts (passage_id, id, text, is_target) VALUES (?, ?, ?, ?)",
                bindings: [.text(passage.id), .text(prompt.id), .text(prompt.text), .int(prompt.isTarget ? 1 : 0)]
            )
        }
        for (index, keyword) in passage.passage.recallKeywords.enumerated() {
            try execute(
                "INSERT INTO reading_recall_keywords (passage_id, position, keyword) VALUES (?, ?, ?)",
                bindings: [.text(passage.id), .int(index), .text(keyword)]
            )
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

    func loadApprovedSyllogismTrials() throws -> [SyllogismTrial] {
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
                    premises: try loadSyllogismPremises(trialID: id),
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

    func saveApprovedSyllogismTrials(_ trials: [SyllogismTrial]) throws {
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
                try execute(
                    "INSERT INTO syllogism_premises (trial_id, position, text) VALUES (?, ?, ?)",
                    bindings: [.text(trial.id), .int(index), .text(premise)]
                )
            }
        }
    }

    private func loadMainIdeaOptions(passageID: String) throws -> [String] {
        try loadOrderedStrings("SELECT text FROM reading_main_idea_options WHERE passage_id = ? ORDER BY position", id: passageID)
    }

    private func loadRubricKeywords(passageID: String) throws -> [String] {
        try loadOrderedStrings("SELECT keyword FROM reading_rubric_keywords WHERE passage_id = ? ORDER BY position", id: passageID)
    }

    private func loadRecallKeywords(passageID: String) throws -> [String] {
        try loadOrderedStrings("SELECT keyword FROM reading_recall_keywords WHERE passage_id = ? ORDER BY position", id: passageID)
    }

    private func loadSyllogismPremises(trialID: String) throws -> [String] {
        try loadOrderedStrings("SELECT text FROM syllogism_premises WHERE trial_id = ? ORDER BY position", id: trialID)
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
                values.append(EvidenceClassificationItem(
                    id: columnString(statement, 0),
                    text: columnString(statement, 1),
                    role: role,
                    supportsClaimID: columnOptionalString(statement, 3)
                ))
            }
            return values
        }
    }

    private func loadRecallPrompts(passageID: String) throws -> [DelayedRecallPrompt] {
        try withStatement("SELECT id, text, is_target FROM reading_recall_prompts WHERE passage_id = ? ORDER BY rowid", bindings: [.text(passageID)]) { statement in
            var values: [DelayedRecallPrompt] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                values.append(DelayedRecallPrompt(
                    id: columnString(statement, 0),
                    text: columnString(statement, 1),
                    isTarget: sqlite3_column_int(statement, 2) == 1
                ))
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

    func loadApprovedBankQuestions() throws -> [BankQuestion] {
        try fetchAppDocument("approved-bank-questions", as: [BankQuestion].self) ?? []
    }

    func saveApprovedBankQuestions(_ questions: [BankQuestion]) throws {
        try saveAppDocument(key: "approved-bank-questions", value: questions)
    }

    func loadStreakTracker() throws -> StreakTracker? {
        try fetchAppDocument("streak-tracker", as: StreakTracker.self)
    }

    func saveStreakTracker(_ tracker: StreakTracker) throws {
        try saveAppDocument(key: "streak-tracker", value: tracker)
    }

    func loadAchievementTracker() throws -> AchievementTracker? {
        try fetchAppDocument("achievement-tracker", as: AchievementTracker.self)
    }

    func saveAchievementTracker(_ tracker: AchievementTracker) throws {
        try saveAppDocument(key: "achievement-tracker", value: tracker)
    }

    /// Bump when a migration step is added below. Stored in SQLite's
    /// `PRAGMA user_version`.
    ///   v3: drop sessions/adaptive_states for modules removed from the build.
    ///   v4: re-purge rows for modules removed from the build (choiceRT).
    static let currentSchemaVersion = 4

    private func bootstrap() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try execute("PRAGMA journal_mode = WAL")
        try execute("PRAGMA foreign_keys = ON")
        try createSchema()
        try migrateLegacyJSONIfNeeded()
        try migrateSchemaIfNeeded()
    }

    /// Run forward migrations based on the persisted schema version, then stamp the
    /// current version. Replaces ad-hoc filtering at query time with a one-time,
    /// versioned data fix-up.
    private func migrateSchemaIfNeeded() throws {
        let version = try schemaVersion()
        guard version < Self.currentSchemaVersion else { return }

        // v3 — purge rows referencing modules that no longer exist in this build,
        // so `SessionResult`/adaptive-state decoding never hits an unknown module.
        if version < 3 {
            try purgeUnknownModuleRows()
        }

        // v4 — re-purge after removing the choiceRT module, since installs already
        // stamped at v3 would otherwise retain undecodable choiceRT rows.
        if version < 4 {
            try purgeUnknownModuleRows()
        }

        try execute("PRAGMA user_version = \(Self.currentSchemaVersion)")
    }

    private func schemaVersion() throws -> Int {
        try withStatement("PRAGMA user_version") { statement in
            guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int64(statement, 0))
        }
    }

    /// Delete any session / adaptive-state row whose `module` is not a known
    /// `TrainingModule` (e.g. modules deleted in a later release).
    private func purgeUnknownModuleRows() throws {
        let knownModules = TrainingModule.allCases
            .map { "'\($0.rawValue)'" }
            .joined(separator: ", ")
        try execute("DELETE FROM sessions WHERE module NOT IN (\(knownModules))")
        try execute("DELETE FROM adaptive_states WHERE module NOT IN (\(knownModules))")
    }

    private func createSchema() throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                module TEXT NOT NULL,
                started_at TEXT NOT NULL,
                ended_at TEXT NOT NULL,
                json BLOB NOT NULL
            )
            """
        )
        try execute("CREATE INDEX IF NOT EXISTS idx_sessions_module_ended ON sessions(module, ended_at DESC)")

        try execute(
            """
            CREATE TABLE IF NOT EXISTS settings (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                json BLOB NOT NULL
            )
            """
        )

        try execute(
            """
            CREATE TABLE IF NOT EXISTS adaptive_states (
                module TEXT PRIMARY KEY,
                json BLOB NOT NULL
            )
            """
        )

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
        try execute("CREATE INDEX IF NOT EXISTS idx_syllogism_trials_difficulty ON syllogism_trials(difficulty_min, difficulty_max)")
        try execute("CREATE TABLE IF NOT EXISTS syllogism_premises (trial_id TEXT NOT NULL, position INTEGER NOT NULL, text TEXT NOT NULL, PRIMARY KEY (trial_id, position), FOREIGN KEY (trial_id) REFERENCES syllogism_trials(id) ON DELETE CASCADE)")

        try execute(
            """
            CREATE TABLE IF NOT EXISTS app_documents (
                key TEXT PRIMARY KEY,
                json BLOB NOT NULL
            )
            """
        )
    }

    private func migrateLegacyJSONIfNeeded() throws {
        if try tableIsEmpty("sessions"), fileManager.fileExists(atPath: legacyJSONURL.path) {
            let data = try Data(contentsOf: legacyJSONURL)

            if let v2 = try? decoder.decode(PersistedStateV2.self, from: data), v2.version == 2 {
                try saveSessions(v2.sessions)
                try saveSettings(v2.settings)
                let states = v2.adaptiveStates.reduce(into: [TrainingModule: ModuleAdaptiveState]()) { partial, item in
                    guard let module = TrainingModule(rawValue: item.key) else { return }
                    partial[module] = item.value
                }
                try saveAdaptiveStates(states)
            } else if let legacy = try? decoder.decode(LegacyState.self, from: data) {
                if let results = legacy.results {
                    try saveSessions(results.map { SessionResult.fromLegacy($0) })
                }
                if let legacySettings = legacy.settings {
                    var settings = TrainingSettings.default
                    settings.showHints = legacySettings.showHints
                    settings.preferredDifficulty = legacySettings.preferredDifficulty
                    settings.adaptiveDifficultyEnabled = legacySettings.adaptiveDifficultyEnabled
                    settings.adaptiveConfig = legacySettings.adaptiveConfig
                    try saveSettings(settings)
                }
            }
        }

        if try tableIsEmpty("reading_passages") {
            let url = directoryURL.appendingPathComponent("approved-reading-passages.json")
            if fileManager.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url)
                if let passages = try? decoder.decode([ApprovedReadingPassage].self, from: data) {
                    try saveApprovedReadingPassages(passages)
                }
            }
        }

        if try tableIsEmpty("syllogism_trials") {
            let url = directoryURL.appendingPathComponent("approved-syllogism-trials.json")
            if fileManager.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url)
                if let trials = try? decoder.decode([SyllogismTrial].self, from: data) {
                    try saveApprovedSyllogismTrials(trials)
                }
            }
        }

        try migrateAppDocumentIfNeeded(key: "streak-tracker", fileName: "streak-tracker.json", type: StreakTracker.self)
        try migrateAppDocumentIfNeeded(key: "achievement-tracker", fileName: "achievement-tracker.json", type: AchievementTracker.self)
    }

    private func migrateAppDocumentIfNeeded<Value: Codable>(key: String, fileName: String, type: Value.Type) throws {
        guard try fetchAppDocument(key, as: type) == nil else { return }
        let url = directoryURL.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: url.path) else { return }
        let data = try Data(contentsOf: url)
        if let value = try? decoder.decode(type, from: data) {
            try saveAppDocument(key: key, value: value)
        }
    }

    private func fetchAppDocument<Value: Decodable>(_ key: String, as type: Value.Type) throws -> Value? {
        try withStatement("SELECT json FROM app_documents WHERE key = ?", bindings: [.text(key)]) { statement in
            guard sqlite3_step(statement) == SQLITE_ROW, let data = columnData(statement, 0) else { return nil }
            return try decoder.decode(type, from: data)
        }
    }

    private func saveAppDocument<Value: Encodable>(key: String, value: Value) throws {
        try execute(
            "INSERT OR REPLACE INTO app_documents (key, json) VALUES (?, ?)",
            bindings: [
                .text(key),
                .data(try encoder.encode(value))
            ]
        )
    }

    private func fetchRows<Value: Decodable>(_ sql: String, decode type: Value.Type) throws -> [Value] {
        try withStatement(sql) { statement in
            var values: [Value] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let data = columnData(statement, 0) else { continue }
                values.append(try decoder.decode(type, from: data))
            }
            return values
        }
    }

    private func fetchSingleDocument<Value: Decodable>(_ type: Value.Type, sql: String) throws -> Value? {
        try withStatement(sql) { statement in
            guard sqlite3_step(statement) == SQLITE_ROW, let data = columnData(statement, 0) else { return nil }
            return try decoder.decode(type, from: data)
        }
    }

    private func replaceRows(table: String, _ operation: () throws -> Void) throws {
        try execute("DELETE FROM \(table)")
        try operation()
    }

    private func tableIsEmpty(_ table: String) throws -> Bool {
        try withStatement("SELECT COUNT(*) FROM \(table)") { statement in
            guard sqlite3_step(statement) == SQLITE_ROW else { return true }
            return sqlite3_column_int64(statement, 0) == 0
        }
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
                throw TrainingStoreError.stepFailed(lastSQLiteError())
            }
        }
    }

    private func withStatement<T>(
        _ sql: String,
        bindings: [Binding] = [],
        _ operation: (OpaquePointer?) throws -> T
    ) throws -> T {
        var database: OpaquePointer?
        guard sqlite3_open(storageURL.path, &database) == SQLITE_OK else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(database)
            throw TrainingStoreError.openFailed(message)
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(database))
            sqlite3_finalize(statement)
            throw TrainingStoreError.prepareFailed(message)
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
            throw TrainingStoreError.bindFailed(lastSQLiteError(statement: statement))
        }
    }

    private func columnData(_ statement: OpaquePointer?, _ index: Int32) -> Data? {
        guard let bytes = sqlite3_column_blob(statement, index) else { return nil }
        let count = sqlite3_column_bytes(statement, index)
        return Data(bytes: bytes, count: Int(count))
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

    private func lastSQLiteError(statement: OpaquePointer? = nil) -> String {
        guard let database = statement.flatMap({ sqlite3_db_handle($0) }) else { return "unknown" }
        return String(cString: sqlite3_errmsg(database))
    }

    private var sqliteTransient: sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }
}
