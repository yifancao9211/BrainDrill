import Foundation
import Testing
@testable import BrainDrill

struct LocalTrainingStoreTests {
    @Test
    func savesAndLoadsSessionsAndSettings() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LocalTrainingStore(baseURL: tempRoot)

        var settings = TrainingSettings.default
        settings.showHints = false
        settings.preferredDifficulty = .challenge5x5
        settings.adaptiveDifficultyEnabled = true
        settings.flankerStimulusDurationMs = 150
        settings.nBackStartingN = 2
        settings.nBackStimulusDurationMs = 900
        settings.nBackISIMs = 1800
        let session = SessionResult(
            module: .schulte,
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 18),
            duration: 8,
            metrics: .schulte(SchulteMetrics(difficulty: .challenge5x5, mistakeCount: 3, setIndex: 0, repIndex: 0))
        )

        try store.saveSettings(settings)
        try store.saveSessions([session])

        let loadedSettings = try store.loadSettings()
        let loadedSessions = try store.loadSessions()

        #expect(loadedSettings == settings)
        #expect(loadedSessions.count == 1)
        #expect(loadedSessions.first?.module == .schulte)
        #expect(loadedSessions.first?.schulteMetrics?.difficulty == .challenge5x5)
    }

    @Test
    func loadingSettingsMigratesLegacyDefaultAIModel() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LocalTrainingStore(baseURL: tempRoot)

        var settings = TrainingSettings.default
        settings.aiModel = TrainingSettings.legacyDefaultAIModel
        try store.saveSettings(settings)

        let loaded = try store.loadSettings()

        #expect(loaded.aiModel == TrainingSettings.defaultAIModel)
        #expect(try store.loadSettings().aiModel == TrainingSettings.defaultAIModel)
    }

    @Test
    func loadingSourceConfigsMergesNewDefaults() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LocalTrainingStore(baseURL: tempRoot)

        try store.saveSourceConfigs([
            ContentSourceConfig(kind: .openStax, isEnabled: false, lastCompletedAt: nil, lastError: nil, lastStatus: nil),
            ContentSourceConfig(kind: .ourWorldInData, isEnabled: true, lastCompletedAt: nil, lastError: nil, lastStatus: .healthy)
        ])

        let loaded = try store.loadSourceConfigs()

        #expect(loaded.count == ConcreteSourceKind.allCases.count)
        #expect(loaded.first(where: { $0.kind == .openStax })?.isEnabled == false)
        #expect(loaded.contains(where: { $0.kind == .qstheory }))
    }
}
