import Foundation
import Testing
@testable import BrainDrill

struct LocalTrainingStoreTests {
    @Test
    func savesAndLoadsSessionsAndSettings() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LocalTrainingStore(baseURL: tempRoot)

        let settings = TrainingSettings(
            showHints: false,
            enableSoundFeedback: true,
            preferredDifficulty: .challenge5x5,
            adaptiveDifficultyEnabled: true,
            adaptiveConfig: .init(),
            schulteSetRep: .init(),
            showFixationDot: true,
            flankerStimulusDurationMs: 150,
            nBackStartingN: 2,
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
}
