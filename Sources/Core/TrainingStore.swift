import Foundation

protocol TrainingStore {
    var storageURL: URL { get }
    func loadResults() throws -> [SchulteSessionResult]
    func saveResults(_ results: [SchulteSessionResult]) throws
    func loadSettings() throws -> TrainingSettings
    func saveSettings(_ settings: TrainingSettings) throws
}

final class LocalTrainingStore: TrainingStore {
    private struct PersistedTrainingState: Codable {
        var results: [SchulteSessionResult] = []
        var settings: TrainingSettings = .default
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

    func loadResults() throws -> [SchulteSessionResult] {
        try readState().results.sorted { $0.endedAt > $1.endedAt }
    }

    func saveResults(_ results: [SchulteSessionResult]) throws {
        var state = try readState()
        state.results = results.sorted { $0.endedAt > $1.endedAt }
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

    private func readState() throws -> PersistedTrainingState {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return PersistedTrainingState()
        }

        let data = try Data(contentsOf: storageURL)
        return try decoder.decode(PersistedTrainingState.self, from: data)
    }

    private func writeState(_ state: PersistedTrainingState) throws {
        let directoryURL = storageURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(state)
        try data.write(to: storageURL, options: .atomic)
    }
}
