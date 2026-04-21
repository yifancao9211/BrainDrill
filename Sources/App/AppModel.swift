import Foundation
import Observation

enum ModuleFeedbackStatus: Equatable {
    case noData
    case success
    case warning
    case error

    var shortLabel: String {
        switch self {
        case .noData: "未训练"
        case .success: "达标"
        case .warning: "一般"
        case .error: "失准"
        }
    }
}

@MainActor
@Observable
final class AppModel {
    var selectedRoute: AppRoute = .home
    var settings: TrainingSettings
    var sessions: [SessionResult]
    var adaptiveStates: [TrainingModule: ModuleAdaptiveState]
    var sourceConfigs: [ContentSourceConfig]
    var materialCandidates: [MaterialCandidate]
    var approvedReadingPassages: [ApprovedReadingPassage]
    var materialRunRecords: [MaterialRunRecord]
    var isMaterialsRunInProgress: Bool = false
    var materialsStatusMessage: String = "准备抓取开放来源并生成候选。"
    var materialsPipelineProgress: MaterialsPipelineProgress?
    var materialsLiveLogs: [String] = []
    var lastPersistenceError: String?
    var streakTracker: StreakTracker
    var achievementTracker: AchievementTracker
    var recentlyUnlockedAchievements: [Achievement] = []

    let schulte: SchulteCoordinator
    let flanker: FlankerCoordinator
    let goNoGo: GoNoGoCoordinator
    let nBack: NBackCoordinator
    let digitSpan: DigitSpanCoordinator
    let choiceRT: ChoiceRTCoordinator
    let changeDetection: ChangeDetectionCoordinator
    let visualSearch: VisualSearchCoordinator
    let corsiBlock: CorsiBlockCoordinator
    let stopSignal: StopSignalCoordinator
    let syllogismCoord: SyllogismCoordinator
    let logicArgumentCoord: LogicArgumentCoordinator

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
        self.corsiBlock = CorsiBlockCoordinator()
        self.stopSignal = StopSignalCoordinator()
        self.syllogismCoord = SyllogismCoordinator()
        self.logicArgumentCoord = LogicArgumentCoordinator()
        self.settings = (try? store.loadSettings()) ?? .default
        self.sessions = ((try? store.loadSessions()) ?? []).sorted { $0.endedAt > $1.endedAt }
        let loadedAdaptiveStates = (try? store.loadAdaptiveStates()) ?? [:]
        self.adaptiveStates = TrainingModule.allCases.reduce(into: [TrainingModule: ModuleAdaptiveState]()) { partial, module in
            partial[module] = loadedAdaptiveStates[module] ?? .default(for: module)
        }
        self.sourceConfigs = (try? store.loadSourceConfigs()) ?? ContentSourceConfig.defaults
        self.materialCandidates = ((try? store.loadMaterialCandidates()) ?? [])
            .filter { $0.status != .rejected }
            .sorted { $0.updatedAt > $1.updatedAt }
        self.approvedReadingPassages = ((try? store.loadApprovedReadingPassages()) ?? []).sorted { $0.approvedAt > $1.approvedAt }
        self.materialRunRecords = ((try? store.loadMaterialRunRecords()) ?? []).sorted { $0.endedAt > $1.endedAt }
        self.streakTracker = (try? store.loadStreakTracker()) ?? StreakTracker()
        self.achievementTracker = (try? store.loadAchievementTracker()) ?? AchievementTracker()
        ReadingPassageRepository.updateApprovedPassages(self.approvedReadingPassages)
    }

    var statistics: TrainingStatistics {
        TrainingStatistics(sessions: sessions)
    }

    var storageLocationDescription: String {
        store.storageURL.path
    }

    var skillProfile: AppSkillProfile {
        AppSkillProfile.compute(from: adaptiveStates)
    }

    var pendingMaterialCandidates: [MaterialCandidate] {
        materialCandidates
            .filter { $0.status == .pending }
            .sorted { lhs, rhs in
                if lhs.status != rhs.status {
                    return lhs.status.rawValue < rhs.status.rawValue
                }
                return lhs.score > rhs.score
            }
    }

    var latestMaterialRun: MaterialRunRecord? {
        materialRunRecords.first
    }

    var isAnyModuleActive: Bool {
        schulte.isTrainingActive || flanker.isActive || goNoGo.isActive || nBack.isActive
            || digitSpan.isActive || choiceRT.isActive || changeDetection.isActive || visualSearch.isActive
            || corsiBlock.isActive || stopSignal.isActive || syllogismCoord.isActive || logicArgumentCoord.isActive
    }

    var isSelectedTrainingActive: Bool {
        switch selectedRoute {
        case .mainIdea, .evidenceMap, .delayedRecall:
            false
        case .syllogism:
            syllogismCoord.isActive
        case .logicArgument:
            logicArgumentCoord.isActive
        case .schulte:
            schulte.isTrainingActive || schulte.isResting
        case .nBack:
            nBack.isActive
        case .visualSearch:
            visualSearch.isActive
        case .flanker:
            flanker.isActive
        case .goNoGo:
            goNoGo.isActive
        case .stopSignal:
            stopSignal.isActive
        case .digitSpan:
            digitSpan.isActive
        case .corsiBlock:
            corsiBlock.isActive
        case .changeDetection:
            changeDetection.isActive
        case .choiceRT:
            choiceRT.isActive
        default:
            false
        }
    }

    var currentStatusMessage: String {
        switch selectedRoute {
        case .mainIdea:
            "抓一篇短文的主旨"
        case .evidenceMap:
            "判断结论、证据与限制"
        case .delayedRecall:
            "延迟后提取关键点"
        case .syllogism:
            syllogismCoord.statusMessage
        case .logicArgument:
            logicArgumentCoord.statusMessage
        case .schulte:
            schulte.statusMessage
        case .nBack:
            nBack.statusMessage
        case .visualSearch:
            visualSearch.statusMessage
        case .flanker:
            flanker.statusMessage
        case .goNoGo:
            goNoGo.statusMessage
        case .stopSignal:
            stopSignal.statusMessage
        case .digitSpan:
            digitSpan.statusMessage
        case .corsiBlock:
            corsiBlock.statusMessage
        case .changeDetection:
            changeDetection.statusMessage
        case .choiceRT:
            choiceRT.statusMessage
        case .materialsWorkbench:
            materialsStatusMessage
        case .home:
            "查看阅读主线、支撑训练与关键统计"
        case .history:
            "按模块过滤历史训练记录"
        case .settings:
            "调整训练参数与应用配置"
        }
    }

    var cognitiveProfile: CognitiveProfile {
        CognitiveProfile.compute(from: sessions)
    }

    var schulteSessions: [SessionResult] {
        sessions.filter { $0.module == .schulte }
    }

    func latestSession(for module: TrainingModule) -> SessionResult? {
        sessions.first { $0.module == module }
    }

    func feedbackStatus(for module: TrainingModule) -> ModuleFeedbackStatus {
        guard let session = latestSession(for: module) else { return .noData }

        switch session.metrics {
        case let .mainIdea(metrics):
            return metrics.isCorrect ? .success : .error
        case let .evidenceMap(metrics):
            if metrics.accuracy >= 0.85 && metrics.mappingAccuracy >= 0.75 {
                return .success
            }
            if metrics.accuracy >= 0.65 && metrics.mappingAccuracy >= 0.5 {
                return .warning
            }
            return .error
        case let .delayedRecall(metrics):
            if metrics.accuracy >= 0.8 && metrics.freeRecallCoverage >= 0.4 {
                return .success
            }
            if metrics.accuracy >= 0.55 {
                return .warning
            }
            return .error
        case let .schulte(metrics):
            if metrics.mistakeCount == 0 {
                return .success
            }
            if metrics.mistakeCount <= 2 {
                return .warning
            }
            return .error
        case let .nBack(metrics):
            if metrics.dPrime >= 1.2 && metrics.hitRate >= 0.7 && metrics.falseAlarmRate <= 0.2 {
                return .success
            }
            if metrics.dPrime >= 0.6 && metrics.hitRate >= 0.55 {
                return .warning
            }
            return .error
        case let .visualSearch(metrics):
            if metrics.accuracy >= 0.85 && metrics.errorRate <= 0.15 {
                return .success
            }
            if metrics.accuracy >= 0.7 && metrics.errorRate <= 0.3 {
                return .warning
            }
            return .error
        case .flanker, .goNoGo, .digitSpan, .choiceRT, .changeDetection, .corsiBlock, .stopSignal:
            return .noData
        case let .syllogism(metrics):
            if metrics.accuracy >= 0.80 && metrics.dPrime >= 1.5 { return .success }
            if metrics.accuracy >= 0.60 { return .warning }
            return .error
        case let .logicArgument(metrics):
            if metrics.compositeScore >= 0.80 { return .success }
            if metrics.compositeScore >= 0.55 { return .warning }
            return .error
        }
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
            let sessionResult = SessionResult(
                id: result.id,
                module: .schulte,
                startedAt: result.startedAt,
                endedAt: result.endedAt,
                duration: result.duration,
                metrics: .schulte(SchulteMetrics(
                    difficulty: result.difficulty,
                    mistakeCount: result.mistakeCount,
                    setIndex: schulte.currentSet,
                    repIndex: schulte.currentRep,
                    perNumberDurations: result.perNumberDurations
                )),
                conditions: schulteSessionConditions(for: result)
            )
            appendSession(sessionResult)
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
        flanker.startSession(settings: settings, adaptiveState: adaptiveState(for: .flanker))
    }

    func handleFlankerResponse(_ direction: FlankerDirection, at date: Date = Date()) {
        if let result = flanker.handleResponse(direction, at: date) {
            appendSession(result)
        }
    }

    func finalizeFlankerIfComplete() {
        if let result = flanker.finalizeIfComplete() {
            appendSession(result)
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
        goNoGo.startSession(settings: settings, adaptiveState: adaptiveState(for: .goNoGo))
    }

    func handleGoNoGoTap(at date: Date = Date()) {
        if let result = goNoGo.handleTap(at: date) {
            appendSession(result)
        }
    }

    func finalizeGoNoGoIfComplete() {
        if let result = goNoGo.finalizeIfComplete() {
            appendSession(result)
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
        nBack.startSession(settings: settings, adaptiveState: adaptiveState(for: .nBack))
    }

    func handleNBackMatch(at date: Date = Date()) {
        if let result = nBack.handleMatch(at: date) {
            appendSession(result)
        }
    }

    func cancelNBackSession() {
        nBack.cancelSession()
    }

    func recordNBackResult(_ result: SessionResult) {
        appendSession(result)
    }

    func dismissNBackResult() {
        nBack.lastResult = nil
    }

    // MARK: - Reading modules

    func recordMainIdeaResult(_ metrics: MainIdeaMetrics, startedAt: Date, endedAt: Date) {
        appendSession(
            SessionResult(
                module: .mainIdea,
                startedAt: startedAt,
                endedAt: endedAt,
                duration: endedAt.timeIntervalSince(startedAt),
                metrics: .mainIdea(metrics)
            )
        )
    }

    func recordEvidenceMapResult(_ metrics: EvidenceMapMetrics, startedAt: Date, endedAt: Date) {
        appendSession(
            SessionResult(
                module: .evidenceMap,
                startedAt: startedAt,
                endedAt: endedAt,
                duration: endedAt.timeIntervalSince(startedAt),
                metrics: .evidenceMap(metrics)
            )
        )
    }

    func recordDelayedRecallResult(_ metrics: DelayedRecallMetrics, startedAt: Date, endedAt: Date) {
        appendSession(
            SessionResult(
                module: .delayedRecall,
                startedAt: startedAt,
                endedAt: endedAt,
                duration: endedAt.timeIntervalSince(startedAt),
                metrics: .delayedRecall(metrics)
            )
        )
    }

    // MARK: - DigitSpan delegation

    func startDigitSpanSession(mode: DigitSpanMode = .forward) {
        digitSpan.startSession(settings: settings, adaptiveState: adaptiveState(for: .digitSpan), mode: mode)
    }

    func recordDigitSpanResult(_ result: SessionResult) {
        appendSession(result)
    }

    func cancelDigitSpanSession() {
        digitSpan.cancelSession()
    }

    func dismissDigitSpanResult() {
        digitSpan.lastResult = nil
    }

    // MARK: - ChoiceRT delegation

    func startChoiceRTSession() {
        choiceRT.startSession(settings: settings, adaptiveState: adaptiveState(for: .choiceRT))
    }

    func handleChoiceRTResponse(_ responseIndex: Int, at date: Date = Date()) -> SessionResult? {
        if let result = choiceRT.handleResponse(responseIndex, at: date) {
            appendSession(result)
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
            metrics: .choiceRT(metrics),
            conditions: choiceRT.sessionConditions
        )
        choiceRT.lastResult = result
        choiceRT.engine = nil
        appendSession(result)
    }

    func cancelChoiceRTSession() {
        choiceRT.cancelSession()
    }

    func dismissChoiceRTResult() {
        choiceRT.lastResult = nil
    }

    // MARK: - ChangeDetection delegation

    func startChangeDetectionSession() {
        changeDetection.startSession(settings: settings, adaptiveState: adaptiveState(for: .changeDetection))
    }

    func handleChangeDetectionResponse(changed: Bool, at date: Date = Date()) -> SessionResult? {
        if let result = changeDetection.handleResponse(userSaidChanged: changed, at: date) {
            appendSession(result)
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
            metrics: .changeDetection(metrics),
            conditions: changeDetection.sessionConditions
        )
        changeDetection.lastResult = result
        changeDetection.engine = nil
        appendSession(result)
    }

    func cancelChangeDetectionSession() {
        changeDetection.cancelSession()
    }

    func dismissChangeDetectionResult() {
        changeDetection.lastResult = nil
    }

    // MARK: - VisualSearch delegation

    func startVisualSearchSession() {
        visualSearch.startSession(settings: settings, adaptiveState: adaptiveState(for: .visualSearch))
    }

    func handleVisualSearchResponse(present: Bool, at date: Date = Date()) -> SessionResult? {
        if let result = visualSearch.handleResponse(userSaidPresent: present, at: date) {
            appendSession(result)
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
            metrics: .visualSearch(metrics),
            conditions: visualSearch.sessionConditions
        )
        visualSearch.lastResult = result
        visualSearch.engine = nil
        appendSession(result)
    }

    func cancelVisualSearchSession() {
        visualSearch.cancelSession()
    }

    func dismissVisualSearchResult() {
        visualSearch.lastResult = nil
    }

    // MARK: - CorsiBlock delegation

    func startCorsiBlockSession(mode: CorsiBlockMode = .forward) {
        corsiBlock.startSession(settings: settings, adaptiveState: adaptiveState(for: .corsiBlock), mode: mode)
    }

    func recordCorsiBlockResult(_ result: SessionResult) {
        appendSession(result)
    }

    func cancelCorsiBlockSession() {
        corsiBlock.cancelSession()
    }

    func dismissCorsiBlockResult() {
        corsiBlock.lastResult = nil
    }

    // MARK: - StopSignal delegation

    func startStopSignalSession() {
        stopSignal.startSession(adaptiveState: adaptiveState(for: .stopSignal))
    }

    func handleStopSignalResponse(_ direction: StopSignalDirection, at date: Date = Date()) -> SessionResult? {
        if let result = stopSignal.handleResponse(direction, at: date) {
            appendSession(result)
            return result
        }
        return nil
    }

    func handleStopSignalStopTimeout() {
        stopSignal.handleStopTimeout()
    }

    func handleStopSignalGoTimeout() {
        stopSignal.handleGoTimeout()
    }

    func finalizeStopSignalIfComplete() {
        guard let engine = stopSignal.engine, engine.isComplete else { return }
        let metrics = engine.computeMetrics()
        let now = Date()
        let result = SessionResult(
            module: .stopSignal,
            startedAt: engine.startedAt,
            endedAt: now,
            duration: now.timeIntervalSince(engine.startedAt),
            metrics: .stopSignal(metrics),
            conditions: stopSignal.sessionConditions
        )
        stopSignal.lastResult = result
        stopSignal.engine = nil
        appendSession(result)
    }

    func cancelStopSignalSession() {
        stopSignal.cancelSession()
    }

    func dismissStopSignalResult() {
        stopSignal.lastResult = nil
    }

    // MARK: - Data Export

    func exportSessionsCSV() -> String {
        TrialExporter.exportCSV(sessions: sessions)
    }

    // MARK: - Settings

    func updateShowHints(_ isEnabled: Bool) {
        settings.showHints = isEnabled
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

    func updateAIBaseURL(_ value: String) {
        settings.aiBaseURL = value
        persistSettings()
    }

    func updateAIAPIKey(_ value: String) {
        settings.aiAPIKey = value
        persistSettings()
    }

    func updateAIModel(_ value: String) {
        settings.aiModel = value
        persistSettings()
    }

    func updateMaterialsAutoSourceCount(_ value: Int) {
        settings.materialsAutoSourceCountPerRun = value
        persistSettings()
    }

    func updateMaterialsCandidateThreshold(_ value: Double) {
        settings.materialsCandidateThreshold = value
        persistSettings()
    }

    func updateSourceEnabled(_ kind: ConcreteSourceKind, isEnabled: Bool) {
        guard let index = sourceConfigs.firstIndex(where: { $0.kind == kind }) else { return }
        sourceConfigs[index].isEnabled = isEnabled
        persistSourceConfigs()
    }

    // MARK: - Materials

    func runMaterialsHarvest() {
        guard !isMaterialsRunInProgress else { return }

        isMaterialsRunInProgress = true
        materialsStatusMessage = "正在抓取来源并清洗候选..."
        materialsPipelineProgress = nil
        materialsLiveLogs.removeAll()
        let snapshotSettings = settings
        let snapshotConfigs = sourceConfigs

        Task {
            let outcome = await MaterialsPipeline().run(
                sourceConfigs: snapshotConfigs,
                settings: snapshotSettings,
                recentMaterialHints: recentMaterialHints()
            ) { progress in
                Task { @MainActor in
                    self.materialsPipelineProgress = progress
                    if let msg = progress.logMessage {
                        self.materialsLiveLogs.append(msg)
                    }
                }
            }

            await MainActor.run {
                sourceConfigs = outcome.updatedSourceConfigs
                materialCandidates = mergeCandidates(materialCandidates, with: outcome.candidates)
                materialRunRecords = mergeRunRecords(materialRunRecords, with: outcome.runRecord)
                isMaterialsRunInProgress = false
                materialsStatusMessage = harvestSummary(for: outcome.runRecord)
                persistSourceConfigs()
                persistMaterialCandidates()
                persistMaterialRunRecords()
            }
        }
    }

    func rejectMaterialCandidate(_ candidateID: String) {
        materialCandidates.removeAll { $0.id == candidateID }
        materialsStatusMessage = "候选已删除。"
        persistMaterialCandidates()
    }

    func reprocessMaterialCandidate(_ candidateID: String) {
        guard
            !isMaterialsRunInProgress,
            let index = materialCandidates.firstIndex(where: { $0.id == candidateID })
        else { return }

        isMaterialsRunInProgress = true
        materialsStatusMessage = "正在重新清洗 \(materialCandidates[index].sourceArticle.title)..."
        materialsPipelineProgress = nil
        materialsLiveLogs.removeAll()
        let article = materialCandidates[index].sourceArticle
        let snapshotSettings = settings

        Task {
            let rebuilt = await MaterialsPipeline().rebuildCandidate(
                from: article,
                settings: snapshotSettings,
                existingID: candidateID,
                recentMaterialHints: recentMaterialHints(excludingCandidateID: candidateID)
            ) { progress in
                Task { @MainActor in
                    self.materialsPipelineProgress = progress
                    if let msg = progress.logMessage {
                        self.materialsLiveLogs.append(msg)
                    }
                }
            }

            await MainActor.run {
                materialCandidates[index] = rebuilt
                materialCandidates[index].status = .pending
                materialCandidates[index].updatedAt = Date()
                isMaterialsRunInProgress = false
                materialsStatusMessage = rebuilt.failureReasons.isEmpty ? "候选已重新清洗。" : "候选重新清洗完成，但仍有风险提示。"
                persistMaterialCandidates()
            }
        }
    }

    func approveMaterialCandidate(_ candidateID: String) {
        guard
            let candidateIndex = materialCandidates.firstIndex(where: { $0.id == candidateID }),
            let passage = materialCandidates[candidateIndex].generatedPassage
        else { return }

        let issues = passage.validationIssues
        guard issues.isEmpty else {
            materialCandidates[candidateIndex].failureReasons = issues
            materialsStatusMessage = "入库前校验未通过。"
            persistMaterialCandidates()
            return
        }

        let candidate = materialCandidates[candidateIndex]
        let approved = ApprovedReadingPassage(
            passage: passage,
            sourceArticle: candidate.sourceArticle,
            approvedAt: Date(),
            candidateID: candidate.id,
            score: candidate.score
        )

        if let existingIndex = approvedReadingPassages.firstIndex(where: { $0.id == approved.id }) {
            approvedReadingPassages[existingIndex] = approved
        } else {
            approvedReadingPassages.insert(approved, at: 0)
        }

        materialCandidates[candidateIndex].status = .approved
        materialCandidates[candidateIndex].updatedAt = Date()
        ReadingPassageRepository.updateApprovedPassages(approvedReadingPassages)
        materialsStatusMessage = "素材已通过审核并加入正式题库。"
        persistApprovedReadingPassages()
        persistApprovedReadingPassages()
        persistMaterialCandidates()
    }

    func clearAllMaterialsData() {
        guard !isMaterialsRunInProgress else { return }
        materialCandidates.removeAll()
        approvedReadingPassages.removeAll()
        materialRunRecords.removeAll()
        for i in 0..<sourceConfigs.count {
            sourceConfigs[i].lastError = nil
            sourceConfigs[i].lastStatus = nil
            sourceConfigs[i].lastCompletedAt = nil
        }
        ReadingPassageRepository.updateApprovedPassages([])
        materialsStatusMessage = "素材工作台缓存与抓取日志已全部清空。"
        persistMaterialCandidates()
        persistApprovedReadingPassages()
        persistMaterialRunRecords()
        persistSourceConfigs()
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

    private func persistAdaptiveStates() {
        do {
            try store.saveAdaptiveStates(adaptiveStates)
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = "自适应状态保存失败：\(error.localizedDescription)"
        }
    }

    private func persistSourceConfigs() {
        do {
            try store.saveSourceConfigs(sourceConfigs)
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = "来源设置保存失败：\(error.localizedDescription)"
        }
    }

    private func persistMaterialCandidates() {
        do {
            try store.saveMaterialCandidates(materialCandidates)
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = "候选材料保存失败：\(error.localizedDescription)"
        }
    }

    private func persistApprovedReadingPassages() {
        do {
            try store.saveApprovedReadingPassages(approvedReadingPassages)
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = "正式材料保存失败：\(error.localizedDescription)"
        }
    }

    private func persistMaterialRunRecords() {
        do {
            try store.saveMaterialRunRecords(materialRunRecords)
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = "执行记录保存失败：\(error.localizedDescription)"
        }
    }

    func adaptiveState(for module: TrainingModule) -> ModuleAdaptiveState {
        adaptiveStates[module] ?? .default(for: module)
    }

    private func schulteSessionConditions(for result: SchulteSessionResult) -> SessionConditions {
        guard settings.adaptiveDifficultyEnabled else {
            return SessionConditions(adaptiveEnabled: false)
        }

        let history = [result] + schulteSessions.compactMap { session -> SchulteSessionResult? in
            guard let metrics = session.schulteMetrics else { return nil }
            return SchulteSessionResult(
                id: session.id,
                startedAt: session.startedAt,
                endedAt: session.endedAt,
                duration: session.duration,
                difficulty: metrics.difficulty,
                mistakeCount: metrics.mistakeCount,
                perNumberDurations: metrics.perNumberDurations
            )
        }
        let evaluation = AdaptiveDifficulty.evaluate(
            currentDifficulty: result.difficulty,
            history: history,
            config: settings.adaptiveConfig
        )

        let recommendedDifficulty: SchulteDifficulty
        switch evaluation.recommendation {
        case let .promote(to):
            recommendedDifficulty = to
        case let .demote(to):
            recommendedDifficulty = to
        case .stay:
            recommendedDifficulty = result.difficulty
        }

        return SessionConditions(
            adaptiveEnabled: true,
            customParameters: [
                "recommendedStartLevel": "\(recommendedDifficulty.gridSize - 2)"
            ]
        )
    }

    private func mergeCandidates(_ existing: [MaterialCandidate], with incoming: [MaterialCandidate]) -> [MaterialCandidate] {
        var byURL = Dictionary(uniqueKeysWithValues: existing.map { ($0.sourceArticle.url, $0) })
        for candidate in incoming {
            byURL[candidate.sourceArticle.url] = candidate
        }
        return byURL.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func mergeRunRecords(_ existing: [MaterialRunRecord], with incoming: MaterialRunRecord) -> [MaterialRunRecord] {
        ([incoming] + existing)
            .sorted { $0.endedAt > $1.endedAt }
            .prefix(20)
            .map { $0 }
    }

    private func harvestSummary(for record: MaterialRunRecord) -> String {
        if record.candidateCount > 0 {
            return "已生成 \(record.candidateCount) 条候选，等待审核。"
        }
        if let firstError = record.errorMessages.first {
            return firstError
        }
        return "本轮没有生成可用候选。"
    }

    private func recentMaterialHints(excludingCandidateID: String? = nil) -> [String] {
        let candidateHints = materialCandidates
            .filter { $0.id != excludingCandidateID }
            .prefix(8)
            .map { candidate in
                let title = candidate.displayTitle
                let keywords = candidate.generatedPassage?.recallKeywords.prefix(5).joined(separator: "、") ?? ""
                return "候选：\(title)；关键词：\(keywords)"
            }
        let approvedHints = approvedReadingPassages
            .prefix(8)
            .map { approved in
                "正式：\(approved.passage.title)；关键词：\(approved.passage.recallKeywords.prefix(5).joined(separator: "、"))"
            }
        return Array(candidateHints + approvedHints)
    }

    func appendSessionPublic(_ result: SessionResult) {
        appendSession(result)
    }

    private func appendSession(_ result: SessionResult) {
        sessions.insert(result, at: 0)
        sessions.sort { $0.endedAt > $1.endedAt }
        applyAdaptiveAdjustmentsIfNeeded(for: result)

        // Update streak
        streakTracker.recordTrainingDay(on: result.endedAt)
        persistStreakTracker()

        // Evaluate achievements
        let newAchievements = achievementTracker.evaluate(
            sessions: sessions,
            streak: streakTracker,
            cognitiveProfile: cognitiveProfile
        )
        if !newAchievements.isEmpty {
            recentlyUnlockedAchievements = newAchievements
            persistAchievementTracker()
        }

        persistSessions()
    }

    private func applyAdaptiveAdjustmentsIfNeeded(for result: SessionResult) {
        guard settings.adaptiveDifficultyEnabled else { return }
        guard result.module.dimension != .reading else { return }
        guard result.module.dimension != .logicalReasoning else {
            // Logic modules manage their own adaptive state through coordinators
            let currentState = adaptiveState(for: result.module)
            let updatedState = AdaptiveScoring.updatedState(for: result, current: currentState)
            adaptiveStates[result.module] = updatedState
            persistAdaptiveStates()
            return
        }
        let currentState = adaptiveState(for: result.module)
        let updatedState = AdaptiveScoring.updatedState(for: result, current: currentState)
        adaptiveStates[result.module] = updatedState
        syncLegacySettings(with: updatedState, for: result.module)
        persistAdaptiveStates()
        persistSettings()
    }

    private func syncLegacySettings(with state: ModuleAdaptiveState, for module: TrainingModule) {
        switch module {
        case .digitSpan:
            settings.digitSpanStartingLength = min(max(state.recommendedStartLevel, 2), 8)
        case .corsiBlock:
            settings.corsiBlockStartingLength = min(max(state.recommendedStartLevel, 2), 8)
        case .nBack:
            settings.nBackStartingN = min(max(state.recommendedStartLevel, 1), 5)
        case .changeDetection:
            settings.changeDetectionInitialSetSize = min(max(state.recommendedStartLevel + 1, 2), 6)
        case .schulte:
            let level = min(max(state.recommendedStartLevel, 1), 7)
            settings.preferredDifficulty = SchulteDifficulty.allCases[level - 1]
        default:
            break
        }
    }

    private func persistStreakTracker() {
        do {
            try store.saveStreakTracker(streakTracker)
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = "连胜数据保存失败：\(error.localizedDescription)"
        }
    }

    private func persistAchievementTracker() {
        do {
            try store.saveAchievementTracker(achievementTracker)
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = "成就数据保存失败：\(error.localizedDescription)"
        }
    }
}
