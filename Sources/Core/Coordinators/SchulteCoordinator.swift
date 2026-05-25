import Foundation
import Observation

@Observable
final class SchulteCoordinator: @unchecked Sendable {
    var activeEngine: SchulteEngine?
    var statusMessage: String
    var lastCompletedSummary: CompletedSchulteSummary?

    var currentSet: Int = 0
    var currentRep: Int = 0
    var preparationCountdown: Int = 0
    var isPreparing: Bool = false
    var restCountdown: Int = 0
    var isResting: Bool = false
    var sessionSetRepConfig: SchulteSetRepConfig = .init()
    var sessionPreparationSeconds: Int = 3

    @ObservationIgnored nonisolated(unsafe) private var restTask: Task<Void, Never>?
    @ObservationIgnored nonisolated(unsafe) private var preparationTask: Task<Void, Never>?

    var isTrainingActive: Bool { activeEngine != nil || isResting || isPreparing }

    var totalRepsInSession: Int {
        sessionSetRepConfig.setsPerSession * sessionSetRepConfig.repsPerSet
    }

    var completedReps: Int {
        currentSet * sessionSetRepConfig.repsPerSet + currentRep
    }

    init() {
        self.statusMessage = "选择难度后点击「开始训练」。"
    }

    func startSession(settings: TrainingSettings, preparationSeconds: Int = 3) {
        sessionSetRepConfig = settings.schulteSetRep
        sessionPreparationSeconds = max(0, preparationSeconds)
        currentSet = 0
        currentRep = 0
        lastCompletedSummary = nil
        startPreparation(settings: settings)
    }

    func startSingleRep(settings: TrainingSettings) {
        let config = SchulteSessionConfig(
            difficulty: settings.preferredDifficulty,
            showHints: settings.showHints,
            startMode: .manual,
            showFixationDot: settings.showFixationDot
        )
        activeEngine = SchulteEngine(config: config)
        isPreparing = false
        isResting = false
        preparationTask?.cancel()
        restTask?.cancel()
        statusMessage = "第\(currentSet + 1)组 第\(currentRep + 1)次 — 按顺序点击 1 → \(config.difficulty.totalTiles)"
    }

    func cancelSession() {
        activeEngine = nil
        isPreparing = false
        isResting = false
        preparationTask?.cancel()
        restTask?.cancel()
        preparationCountdown = 0
        restCountdown = 0
        statusMessage = "已取消当前训练。"
    }

    enum TapResult {
        case continued
        case repCompleted(SchulteSessionResult)
    }

    func handleTileTap(_ number: Int, at date: Date = Date()) -> TapResult {
        guard let activeEngine else { return .continued }

        switch activeEngine.handleTap(number, at: date) {
        case .correct:
            statusMessage = "正确，继续下一个。"
            return .continued
        case .incorrect:
            statusMessage = "顺序不对，继续找当前数字。"
            return .continued
        case let .completed(result):
            return .repCompleted(result)
        case .ignored:
            return .continued
        }
    }

    func finishRep(
        result: SchulteSessionResult,
        schulteHistory: [SessionResult],
        settings: TrainingSettings
    ) -> Bool {
        let summary = CompletedSchulteSummary(
            result: result,
            schulteHistory: schulteHistory,
            adaptiveEnabled: settings.adaptiveDifficultyEnabled,
            adaptiveConfig: settings.adaptiveConfig,
            setIndex: currentSet,
            repIndex: currentRep
        )
        lastCompletedSummary = summary
        activeEngine = nil

        currentRep += 1

        let isLastRep = currentRep >= sessionSetRepConfig.repsPerSet
        let isLastSet = currentSet >= sessionSetRepConfig.setsPerSession - 1

        if isLastRep && isLastSet {
            statusMessage = summary.didSetPersonalBest ? "刷新个人最佳！全部完成。" : "本次训练全部完成。"
            return true
        }

        if isLastRep {
            currentSet += 1
            currentRep = 0
            startRest(seconds: sessionSetRepConfig.restBetweenSetsSec, settings: settings, label: "组间休息")
        } else {
            startRest(seconds: sessionSetRepConfig.restBetweenRepsSec, settings: settings, label: "次间休息")
        }

        return false
    }

    func elapsedTimeString(at date: Date) -> String {
        guard let activeEngine else { return "--" }
        return DurationFormatter.training.string(from: activeEngine.elapsedDuration(at: date)) ?? "00:00"
    }

    func remainingDuration(for engine: SchulteEngine, at date: Date) -> TimeInterval {
        max(AdaptiveDifficulty.baseDuration(for: engine.config.difficulty) - engine.elapsedDuration(at: date), 0)
    }

    func countdownTimeString(for engine: SchulteEngine, at date: Date) -> String {
        let baseDuration = AdaptiveDifficulty.baseDuration(for: engine.config.difficulty)
        let elapsed = engine.elapsedDuration(at: date)

        if elapsed <= baseDuration {
            let remaining = max(baseDuration - elapsed, 0)
            let formatted = DurationFormatter.training.string(from: remaining) ?? "00:00"
            return "剩余 \(formatted)"
        }

        let overtime = elapsed - baseDuration
        let formatted = DurationFormatter.training.string(from: overtime) ?? "00:00"
        return "超时 \(formatted)"
    }

    func skipRest(settings: TrainingSettings) {
        restTask?.cancel()
        isResting = false
        restCountdown = 0
        startPreparation(settings: settings)
    }

    private func startRest(seconds: Int, settings: TrainingSettings, label: String) {
        guard seconds > 0 else {
            startPreparation(settings: settings)
            return
        }

        isResting = true
        isPreparing = false
        restCountdown = seconds
        preparationTask?.cancel()
        statusMessage = "\(label) \(seconds)s …"

        restTask?.cancel()
        restTask = Task { @MainActor [weak self] in
            for tick in stride(from: seconds - 1, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                self.restCountdown = tick
                self.statusMessage = "\(label) \(tick)s …"
            }
            guard !Task.isCancelled, let self else { return }
            self.startPreparation(settings: settings)
        }
    }

    private func startPreparation(settings: TrainingSettings) {
        let seconds = sessionPreparationSeconds
        guard seconds > 0 else {
            startSingleRep(settings: settings)
            return
        }

        activeEngine = nil
        isResting = false
        isPreparing = true
        restCountdown = 0
        preparationCountdown = seconds
        restTask?.cancel()
        preparationTask?.cancel()
        statusMessage = "准备开始：\(seconds)"

        preparationTask = Task { @MainActor [weak self] in
            if seconds > 1 {
                for tick in stride(from: seconds - 1, through: 1, by: -1) {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled, let self else { return }
                    self.preparationCountdown = tick
                    self.statusMessage = "准备开始：\(tick)"
                }
            }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, let self else { return }
            self.preparationCountdown = 0
            self.startSingleRep(settings: settings)
        }
    }
}
