import Foundation

protocol TrainingStore {
    var storageURL: URL { get }
    func loadSessions() throws -> [SessionResult]
    func saveSessions(_ sessions: [SessionResult]) throws
    func loadSettings() throws -> TrainingSettings
    func saveSettings(_ settings: TrainingSettings) throws
    func loadAdaptiveStates() throws -> [TrainingModule: ModuleAdaptiveState]
    func saveAdaptiveStates(_ states: [TrainingModule: ModuleAdaptiveState]) throws
    func loadSourceConfigs() throws -> [ContentSourceConfig]
    func saveSourceConfigs(_ configs: [ContentSourceConfig]) throws
    func loadMaterialCandidates() throws -> [MaterialCandidate]
    func saveMaterialCandidates(_ candidates: [MaterialCandidate]) throws
    func loadApprovedReadingPassages() throws -> [ApprovedReadingPassage]
    func saveApprovedReadingPassages(_ passages: [ApprovedReadingPassage]) throws
    func loadMaterialRunRecords() throws -> [MaterialRunRecord]
    func saveMaterialRunRecords(_ records: [MaterialRunRecord]) throws
    func loadStreakTracker() throws -> StreakTracker?
    func saveStreakTracker(_ tracker: StreakTracker) throws
    func loadAchievementTracker() throws -> AchievementTracker?
    func saveAchievementTracker(_ tracker: AchievementTracker) throws
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
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager: FileManager

    init(baseURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let rootURL = baseURL
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.directoryURL = rootURL.appendingPathComponent("BrainDrill", isDirectory: true)
        self.storageURL = directoryURL.appendingPathComponent("training-data.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    static func live() -> LocalTrainingStore {
        LocalTrainingStore()
    }

    func loadSessions() throws -> [SessionResult] {
        try readState().sessions.sorted { $0.endedAt > $1.endedAt }
    }

    func saveSessions(_ sessions: [SessionResult]) throws {
        var state = try readState()
        state.sessions = sessions.sorted { $0.endedAt > $1.endedAt }
        try writeState(state)
    }

    func loadSettings() throws -> TrainingSettings {
        var state = try readState()
        let normalized = state.settings.normalizedForCurrentDefaults()
        if normalized != state.settings {
            state.settings = normalized
            try writeState(state)
        }
        return normalized
    }

    func saveSettings(_ settings: TrainingSettings) throws {
        var state = try readState()
        state.settings = settings
        try writeState(state)
    }

    func loadAdaptiveStates() throws -> [TrainingModule: ModuleAdaptiveState] {
        let rawStates = try readState().adaptiveStates
        return rawStates.reduce(into: [TrainingModule: ModuleAdaptiveState]()) { partial, item in
            guard let module = TrainingModule(rawValue: item.key) else { return }
            partial[module] = item.value
        }
    }

    func saveAdaptiveStates(_ states: [TrainingModule: ModuleAdaptiveState]) throws {
        var state = try readState()
        state.adaptiveStates = states.reduce(into: [String: ModuleAdaptiveState]()) { partial, item in
            partial[item.key.rawValue] = item.value
        }
        try writeState(state)
    }

    func loadSourceConfigs() throws -> [ContentSourceConfig] {
        let loaded = try loadAuxiliary([ContentSourceConfig].self, from: sourceConfigsURL) ?? []
        guard !loaded.isEmpty else { return ContentSourceConfig.defaults }

        var merged = Dictionary(uniqueKeysWithValues: ContentSourceConfig.defaults.map { ($0.kind, $0) })
        for config in loaded {
            merged[config.kind] = config
        }
        return ConcreteSourceKind.allCases.compactMap { merged[$0] }
    }

    func saveSourceConfigs(_ configs: [ContentSourceConfig]) throws {
        try saveAuxiliary(configs, to: sourceConfigsURL)
    }

    func loadMaterialCandidates() throws -> [MaterialCandidate] {
        try loadAuxiliary([MaterialCandidate].self, from: materialCandidatesURL) ?? []
    }

    func saveMaterialCandidates(_ candidates: [MaterialCandidate]) throws {
        try saveAuxiliary(candidates, to: materialCandidatesURL)
    }

    func loadApprovedReadingPassages() throws -> [ApprovedReadingPassage] {
        try loadAuxiliary([ApprovedReadingPassage].self, from: approvedReadingPassagesURL) ?? []
    }

    func saveApprovedReadingPassages(_ passages: [ApprovedReadingPassage]) throws {
        try saveAuxiliary(passages, to: approvedReadingPassagesURL)
    }

    func loadMaterialRunRecords() throws -> [MaterialRunRecord] {
        try loadAuxiliary([MaterialRunRecord].self, from: materialRunRecordsURL) ?? []
    }

    func saveMaterialRunRecords(_ records: [MaterialRunRecord]) throws {
        try saveAuxiliary(records, to: materialRunRecordsURL)
    }

    func loadStreakTracker() throws -> StreakTracker? {
        try loadAuxiliary(StreakTracker.self, from: streakTrackerURL)
    }

    func saveStreakTracker(_ tracker: StreakTracker) throws {
        try saveAuxiliary(tracker, to: streakTrackerURL)
    }

    func loadAchievementTracker() throws -> AchievementTracker? {
        try loadAuxiliary(AchievementTracker.self, from: achievementTrackerURL)
    }

    func saveAchievementTracker(_ tracker: AchievementTracker) throws {
        try saveAuxiliary(tracker, to: achievementTrackerURL)
    }

    private func readState() throws -> PersistedStateV2 {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return PersistedStateV2()
        }

        let data = try Data(contentsOf: storageURL)

        if let v2 = try? decoder.decode(PersistedStateV2.self, from: data), v2.version == 2 {
            return v2
        }

        if let legacy = try? decoder.decode(LegacyState.self, from: data) {
            var state = PersistedStateV2()
            if let results = legacy.results {
                state.sessions = results.map { SessionResult.fromLegacy($0) }
            }
            if let ls = legacy.settings {
                var settings = TrainingSettings.default
                settings.showHints = ls.showHints
                settings.preferredDifficulty = ls.preferredDifficulty
                settings.adaptiveDifficultyEnabled = ls.adaptiveDifficultyEnabled
                settings.adaptiveConfig = ls.adaptiveConfig
                state.settings = settings
            }
            try writeState(state)
            return state
        }

        return PersistedStateV2()
    }

    private func writeState(_ state: PersistedStateV2) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(state)
        try data.write(to: storageURL, options: .atomic)
    }

    private var sourceConfigsURL: URL {
        directoryURL.appendingPathComponent("content-source-configs.json")
    }

    private var materialCandidatesURL: URL {
        directoryURL.appendingPathComponent("material-candidates.json")
    }

    private var approvedReadingPassagesURL: URL {
        directoryURL.appendingPathComponent("approved-reading-passages.json")
    }

    private var materialRunRecordsURL: URL {
        directoryURL.appendingPathComponent("material-run-records.json")
    }

    private var streakTrackerURL: URL {
        directoryURL.appendingPathComponent("streak-tracker.json")
    }

    private var achievementTrackerURL: URL {
        directoryURL.appendingPathComponent("achievement-tracker.json")
    }

    private func loadAuxiliary<Value: Decodable>(_ type: Value.Type, from url: URL) throws -> Value? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(Value.self, from: data)
    }

    private func saveAuxiliary<Value: Encodable>(_ value: Value, to url: URL) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }
}
