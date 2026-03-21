import Foundation
import Observation

@Observable
final class SchulteCoordinator: @unchecked Sendable {
    var activeEngine: SchulteEngine?
    var statusMessage: String
    var lastCompletedSummary: CompletedSchulteSummary?

    var currentSet: Int = 0
    var currentRep: Int = 0
    var restCountdown: Int = 0
    var isResting: Bool = false
    var sessionSetRepConfig: SchulteSetRepConfig = .init()

    @ObservationIgnored nonisolated(unsafe) private var restTask: Task<Void, Never>?

    var isTrainingActive: Bool { activeEngine != nil || isResting }

    var totalRepsInSession: Int {
        sessionSetRepConfig.setsPerSession * sessionSetRepConfig.repsPerSet
    }

    var completedReps: Int {
        currentSet * sessionSetRepConfig.repsPerSet + currentRep
    }

    init() {
        self.statusMessage = "选择难度后点击「开始训练」。"
    }

    func startSession(settings: TrainingSettings) {
        sessionSetRepConfig = settings.schulteSetRep
        currentSet = 0
        currentRep = 0
        lastCompletedSummary = nil
        startSingleRep(settings: settings)
    }

    func startSingleRep(settings: TrainingSettings) {
        let config = SchulteSessionConfig(
            difficulty: settings.preferredDifficulty,
            showHints: settings.showHints,
            startMode: .manual,
            showFixationDot: settings.showFixationDot
        )
        activeEngine = SchulteEngine(config: config)
        isResting = false
        restTask?.cancel()
        statusMessage = "第\(currentSet + 1)组 第\(currentRep + 1)次 — 按顺序点击 1 → \(config.difficulty.totalTiles)"
    }

    func cancelSession() {
        activeEngine = nil
        isResting = false
        restTask?.cancel()
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
        case let .correct(nextNumber):
            statusMessage = "正确 → 下一个 \(nextNumber)"
            return .continued
        case let .incorrect(expected):
            statusMessage = "应点击 \(expected)"
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

    func skipRest(settings: TrainingSettings) {
        restTask?.cancel()
        isResting = false
        restCountdown = 0
        startSingleRep(settings: settings)
    }

    private func startRest(seconds: Int, settings: TrainingSettings, label: String) {
        isResting = true
        restCountdown = seconds
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
            self.startSingleRep(settings: settings)
        }
    }
}
