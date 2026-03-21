import Foundation
import Testing
@testable import BrainDrill

struct LocalTrainingStoreTests {
    @Test
    func savesAndLoadsResultsAndSettings() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LocalTrainingStore(baseURL: tempRoot)
        let settings = TrainingSettings(showHints: false, enableSoundFeedback: true, preferredDifficulty: .challenge5x5)
        let result = SchulteSessionResult(
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 18),
            duration: 8,
            difficulty: .challenge5x5,
            mistakeCount: 3
        )

        try store.saveSettings(settings)
        try store.saveResults([result])

        let loadedSettings = try store.loadSettings()
        let loadedResults = try store.loadResults()

        #expect(loadedSettings == settings)
        #expect(loadedResults == [result])
        #expect(FileManager.default.fileExists(atPath: store.storageURL.path))
    }
}
