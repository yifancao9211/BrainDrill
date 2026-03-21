import Foundation
import Observation

@Observable
final class AppModel {
    var selectedRoute: AppRoute = .dailyPlan
    var settings: TrainingSettings
    var sessions: [SessionResult]
    var lastPersistenceError: String?

    let schulte: SchulteCoordinator
    let flanker: FlankerCoordinator
    let goNoGo: GoNoGoCoordinator
    let nBack: NBackCoordinator
    let digitSpan: DigitSpanCoordinator
    let choiceRT: ChoiceRTCoordinator
    let changeDetection: ChangeDetectionCoordinator
    let visualSearch: VisualSearchCoordinator

    @ObservationIgnored private let store: any TrainingStore

    init(store: any TrainingStore) {
        self.store = store
        self.schulte = SchulteCoordinator()
        self.flanker = FlankerCoordinator()
        self.goNoGo = GoNoGoCoordinator()
        self.nBack = NBackCoordinator()
        self.digitSpan = DigitSpanCoordinator()
        self.choiceRT = ChoiceRTCoordinator()
        self.changeDetection = ChangeDetectionCoordinator()
        self.visualSearch = VisualSearchCoordinator()
        self.settings = (try? store.loadSettings()) ?? .default
        self.sessions = ((try? store.loadSessions()) ?? []).sorted { $0.endedAt > $1.endedAt }
    }

    var statistics: TrainingStatistics {
        TrainingStatistics(sessions: sessions)
    }

    var storageLocationDescription: String {
        store.storageURL.path
    }

    var isAnyModuleActive: Bool {
        schulte.isTrainingActive || flanker.isActive || goNoGo.isActive || nBack.isActive
            || digitSpan.isActive || choiceRT.isActive || changeDetection.isActive || visualSearch.isActive
    }

    var schulteSessions: [SessionResult] {
        sessions.filter { $0.module == .schulte }
    }

    // MARK: - Schulte delegation

    func startSchulteSession() {
        schulte.startSession(settings: settings)
    }

    func cancelSchulteSession() {
        schulte.cancelSession()
    }

    func handleSchulteTileTap(_ number: Int, at date: Date = Date()) {
        switch schulte.handleTileTap(number, at: date) {
        case .continued:
            break
        case let .repCompleted(result):
            let sessionResult = result.toSessionResult(setIndex: schulte.currentSet, repIndex: schulte.currentRep)
            sessions.insert(sessionResult, at: 0)
            sessions.sort { $0.endedAt > $1.endedAt }
            persistSessions()
            _ = schulte.finishRep(result: result, schulteHistory: schulteSessions, settings: settings)
        }
    }

    func acceptSchulteDifficultyRecommendation(_ difficulty: SchulteDifficulty) {
        settings.preferredDifficulty = difficulty
        persistSettings()
    }

    func dismissSchulteResult() {
        schulte.lastCompletedSummary = nil
    }

    // MARK: - Flanker delegation

    func startFlankerSession() {
        flanker.startSession(settings: settings)
    }

    func handleFlankerResponse(_ direction: FlankerDirection, at date: Date = Date()) {
        if let result = flanker.handleResponse(direction, at: date) {
            sessions.insert(result, at: 0)
            sessions.sort { $0.endedAt > $1.endedAt }
            persistSessions()
        }
    }

    func cancelFlankerSession() {
        flanker.cancelSession()
    }

    func dismissFlankerResult() {
        flanker.lastResult = nil
    }

    // MARK: - GoNoGo delegation

    func startGoNoGoSession() {
        goNoGo.startSession(settings: settings)
    }

    func handleGoNoGoTap(at date: Date = Date()) {
        if let result = goNoGo.handleTap(at: date) {
            sessions.insert(result, at: 0)
            sessions.sort { $0.endedAt > $1.endedAt }
            persistSessions()
        }
    }

    func cancelGoNoGoSession() {
        goNoGo.cancelSession()
    }

    func dismissGoNoGoResult() {
        goNoGo.lastResult = nil
    }

    // MARK: - NBack delegation

    func startNBackSession() {
        nBack.startSession(settings: settings)
    }

    func handleNBackMatch(at date: Date = Date()) {
        if let result = nBack.handleMatch(at: date) {
            sessions.insert(result, at: 0)
            sessions.sort { $0.endedAt > $1.endedAt }
            persistSessions()
        }
    }

    func cancelNBackSession() {
        nBack.cancelSession()
    }

    func dismissNBackResult() {
        nBack.lastResult = nil
    }

    // MARK: - DigitSpan delegation

    func startDigitSpanSession(mode: DigitSpanMode = .forward) {
        digitSpan.startSession(settings: settings, mode: mode)
    }

    func recordDigitSpanResult(_ result: SessionResult) {
        sessions.insert(result, at: 0)
        sessions.sort { $0.endedAt > $1.endedAt }
        persistSessions()
    }

    func cancelDigitSpanSession() {
        digitSpan.cancelSession()
    }

    func dismissDigitSpanResult() {
        digitSpan.lastResult = nil
    }

    // MARK: - ChoiceRT delegation

    func startChoiceRTSession() {
        choiceRT.startSession(settings: settings)
    }

    func handleChoiceRTResponse(_ responseIndex: Int, at date: Date = Date()) -> SessionResult? {
        if let result = choiceRT.handleResponse(responseIndex, at: date) {
            sessions.insert(result, at: 0)
            sessions.sort { $0.endedAt > $1.endedAt }
            persistSessions()
            return result
        }
        return nil
    }

    func finalizeChoiceRTIfComplete() {
        guard let engine = choiceRT.engine, engine.isComplete else { return }
        let metrics = engine.computeMetrics()
        let now = Date()
        let result = SessionResult(
            module: .choiceRT,
            startedAt: engine.startedAt,
            endedAt: now,
            duration: now.timeIntervalSince(engine.startedAt),
            metrics: .choiceRT(metrics)
        )
        choiceRT.lastResult = result
        choiceRT.engine = nil
        sessions.insert(result, at: 0)
        sessions.sort { $0.endedAt > $1.endedAt }
        persistSessions()
    }

    func cancelChoiceRTSession() {
        choiceRT.cancelSession()
    }

    func dismissChoiceRTResult() {
        choiceRT.lastResult = nil
    }

    // MARK: - ChangeDetection delegation

    func startChangeDetectionSession() {
        changeDetection.startSession(settings: settings)
    }

    func handleChangeDetectionResponse(changed: Bool, at date: Date = Date()) -> SessionResult? {
        if let result = changeDetection.handleResponse(userSaidChanged: changed, at: date) {
            sessions.insert(result, at: 0)
            sessions.sort { $0.endedAt > $1.endedAt }
            persistSessions()
            return result
        }
        return nil
    }

    func finalizeChangeDetectionIfComplete() {
        guard let engine = changeDetection.engine, engine.isComplete else { return }
        let metrics = engine.computeMetrics()
        let now = Date()
        let result = SessionResult(
            module: .changeDetection,
            startedAt: engine.startedAt,
            endedAt: now,
            duration: now.timeIntervalSince(engine.startedAt),
            metrics: .changeDetection(metrics)
        )
        changeDetection.lastResult = result
        changeDetection.engine = nil
        sessions.insert(result, at: 0)
        sessions.sort { $0.endedAt > $1.endedAt }
        persistSessions()
    }

    func cancelChangeDetectionSession() {
        changeDetection.cancelSession()
    }

    func dismissChangeDetectionResult() {
        changeDetection.lastResult = nil
    }

    // MARK: - VisualSearch delegation

    func startVisualSearchSession() {
        visualSearch.startSession(settings: settings)
    }

    func handleVisualSearchResponse(present: Bool, at date: Date = Date()) -> SessionResult? {
        if let result = visualSearch.handleResponse(userSaidPresent: present, at: date) {
            sessions.insert(result, at: 0)
            sessions.sort { $0.endedAt > $1.endedAt }
            persistSessions()
            return result
        }
        return nil
    }

    func finalizeVisualSearchIfComplete() {
        guard let engine = visualSearch.engine, engine.isComplete else { return }
        let metrics = engine.computeMetrics()
        let now = Date()
        let result = SessionResult(
            module: .visualSearch,
            startedAt: engine.startedAt,
            endedAt: now,
            duration: now.timeIntervalSince(engine.startedAt),
            metrics: .visualSearch(metrics)
        )
        visualSearch.lastResult = result
        visualSearch.engine = nil
        sessions.insert(result, at: 0)
        sessions.sort { $0.endedAt > $1.endedAt }
        persistSessions()
    }

    func cancelVisualSearchSession() {
        visualSearch.cancelSession()
    }

    func dismissVisualSearchResult() {
        visualSearch.lastResult = nil
    }

    // MARK: - Settings

    func updateShowHints(_ isEnabled: Bool) {
        settings.showHints = isEnabled
        persistSettings()
    }

    func updateSoundFeedback(_ isEnabled: Bool) {
        settings.enableSoundFeedback = isEnabled
        persistSettings()
    }

    func updatePreferredDifficulty(_ difficulty: SchulteDifficulty) {
        settings.preferredDifficulty = difficulty
        persistSettings()
    }

    func updateAdaptiveDifficulty(_ enabled: Bool) {
        settings.adaptiveDifficultyEnabled = enabled
        persistSettings()
    }

    func updateShowFixationDot(_ show: Bool) {
        settings.showFixationDot = show
        persistSettings()
    }

    // MARK: - Formatting

    func formattedDuration(_ duration: TimeInterval) -> String {
        DurationFormatter.training.string(from: duration) ?? "00:00"
    }

    func formattedDate(_ date: Date) -> String {
        DateFormatter.trainingTimestamp.string(from: date)
    }

    func formattedMs(_ ms: Int) -> String {
        "\(ms)ms"
    }

    // MARK: - Persistence

    private func persistSessions() {
        do {
            try store.saveSessions(sessions)
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = "保存失败：\(error.localizedDescription)"
        }
    }

    func persistSettings() {
        do {
            try store.saveSettings(settings)
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = "保存失败：\(error.localizedDescription)"
        }
    }
}
