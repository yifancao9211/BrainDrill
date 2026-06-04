import Foundation
import SQLite3
import Testing
@testable import BrainDrill

struct LocalTrainingStoreTests {
    /// Regression: a database containing a session for a since-removed module must
    /// not break history loading. The schema migration purges such rows on open.
    @Test
    func migrationPurgesRemovedModuleSessions() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        // First store creates the schema and stamps the current version.
        let store = LocalTrainingStore(baseURL: tempRoot)
        let validSession = SessionResult(
            module: .schulte,
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 18),
            duration: 8,
            metrics: .schulte(SchulteMetrics(difficulty: .challenge5x5, mistakeCount: 0, setIndex: 0, repIndex: 0))
        )
        try store.saveSessions([validSession])

        // Simulate a legacy DB: insert a row for a removed module and reset the
        // schema version so the next open re-runs the migration.
        var db: OpaquePointer?
        #expect(sqlite3_open(store.storageURL.path, &db) == SQLITE_OK)
        let insert = """
        INSERT INTO sessions (id, module, started_at, ended_at, json)
        VALUES ('legacy', 'flanker', '2020-01-01T00:00:00Z', '2020-01-01T00:00:00Z', x'7b7d')
        """
        #expect(sqlite3_exec(db, insert, nil, nil, nil) == SQLITE_OK)
        #expect(sqlite3_exec(db, "PRAGMA user_version = 0", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)

        // Re-opening triggers the migration, which drops the removed-module row.
        let reopened = LocalTrainingStore(baseURL: tempRoot)
        let sessions = try reopened.loadSessions()

        #expect(sessions.count == 1)
        #expect(sessions.first?.module == .schulte)
    }

    @Test
    func savesAndLoadsSessionsAndSettings() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LocalTrainingStore(baseURL: tempRoot)

        var settings = TrainingSettings.default
        settings.showHints = false
        settings.preferredDifficulty = .challenge5x5
        settings.adaptiveDifficultyEnabled = true
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
    func loadSettingsMigratesLegacySchulteTrainingVolume() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LocalTrainingStore(baseURL: tempRoot)

        var settings = TrainingSettings.default
        settings.schulteSetRep = .previousShortDefault
        try store.saveSettings(settings)

        let loadedSettings = try store.loadSettings()

        #expect(loadedSettings.schulteSetRep == SchulteSetRepConfig())
    }
}
