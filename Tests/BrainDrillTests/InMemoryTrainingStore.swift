import Foundation
@testable import BrainDrill

/// Lightweight in-memory implementation of `TrainingStore` for unit tests.
/// Avoids touching the file system or SQLite for faster, isolated tests.
final class InMemoryTrainingStore: TrainingStore {
    var storageURL: URL { URL(fileURLWithPath: "/dev/null") }

    private var sessions: [SessionResult] = []
    private var settings: TrainingSettings = .default
    private var adaptiveStates: [TrainingModule: ModuleAdaptiveState] = [:]
    private var approvedPassages: [ApprovedReadingPassage] = []
    private var syllogismTrials: [SyllogismTrial] = []
    private var bankQuestions: [BankQuestion] = []
    private var streakTracker: StreakTracker?
    private var achievementTracker: AchievementTracker?

    func loadSessions() throws -> [SessionResult] { sessions }
    func saveSessions(_ sessions: [SessionResult]) throws { self.sessions = sessions }

    func loadSettings() throws -> TrainingSettings { settings }
    func saveSettings(_ settings: TrainingSettings) throws { self.settings = settings }

    func loadAdaptiveStates() throws -> [TrainingModule: ModuleAdaptiveState] { adaptiveStates }
    func saveAdaptiveStates(_ states: [TrainingModule: ModuleAdaptiveState]) throws { self.adaptiveStates = states }

    func loadApprovedReadingPassages() throws -> [ApprovedReadingPassage] { approvedPassages }
    func saveApprovedReadingPassages(_ passages: [ApprovedReadingPassage]) throws { self.approvedPassages = passages }

    func loadApprovedSyllogismTrials() throws -> [SyllogismTrial] { syllogismTrials }
    func saveApprovedSyllogismTrials(_ trials: [SyllogismTrial]) throws { self.syllogismTrials = trials }

    func loadApprovedBankQuestions() throws -> [BankQuestion] { bankQuestions }
    func saveApprovedBankQuestions(_ questions: [BankQuestion]) throws { self.bankQuestions = questions }

    func loadStreakTracker() throws -> StreakTracker? { streakTracker }
    func saveStreakTracker(_ tracker: StreakTracker) throws { self.streakTracker = tracker }

    func loadAchievementTracker() throws -> AchievementTracker? { achievementTracker }
    func saveAchievementTracker(_ tracker: AchievementTracker) throws { self.achievementTracker = tracker }
}
