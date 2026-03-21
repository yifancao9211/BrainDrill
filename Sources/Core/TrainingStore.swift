import Foundation

protocol TrainingStore {
    var storageURL: URL { get }
    func loadSessions() throws -> [SessionResult]
    func saveSessions(_ sessions: [SessionResult]) throws
    func loadSettings() throws -> TrainingSettings
    func saveSettings(_ settings: TrainingSettings) throws
}

final class LocalTrainingStore: TrainingStore {
    private struct PersistedStateV2: Codable {
        var version: Int = 2
        var sessions: [SessionResult] = []
        var settings: TrainingSettings = .default
    }

    private struct LegacyState: Codable {
        var results: [SchulteSessionResult]?
        var settings: LegacySettings?

        struct LegacySettings: Codable {
            var showHints: Bool
            var enableSoundFeedback: Bool
            var preferredDifficulty: SchulteDifficulty
            var adaptiveDifficultyEnabled: Bool
            var adaptiveConfig: AdaptiveDifficulty.Config
        }
    }

    let storageURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager: FileManager

    init(baseURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let rootURL = baseURL
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.storageURL = rootURL
            .appendingPathComponent("BrainDrill", isDirectory: true)
            .appendingPathComponent("training-data.json")
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
        try readState().settings
    }

    func saveSettings(_ settings: TrainingSettings) throws {
        var state = try readState()
        state.settings = settings
        try writeState(state)
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
                state.settings = TrainingSettings(
                    showHints: ls.showHints,
                    enableSoundFeedback: ls.enableSoundFeedback,
                    preferredDifficulty: ls.preferredDifficulty,
                    adaptiveDifficultyEnabled: ls.adaptiveDifficultyEnabled,
                    adaptiveConfig: ls.adaptiveConfig,
                    schulteSetRep: .init(),
                    showFixationDot: true,
                    flankerStimulusDurationMs: 200,
                    nBackStartingN: 1,
                    digitSpanStartingLength: 3,
                    digitSpanPresentationMs: 1000,
                    choiceRTChoiceCount: 2,
                    choiceRTTrialsPerBlock: 30,
                    changeDetectionInitialSetSize: 3,
                    changeDetectionEncodingMs: 500,
                    changeDetectionRetentionMs: 900,
                    visualSearchSetSizes: [8, 16, 24],
                    visualSearchTrialsPerSize: 10,
                    dailyPlanEnabled: true
                )
            }
            try writeState(state)
            return state
        }

        return PersistedStateV2()
    }

    private func writeState(_ state: PersistedStateV2) throws {
        let directoryURL = storageURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(state)
        try data.write(to: storageURL, options: .atomic)
    }
}
