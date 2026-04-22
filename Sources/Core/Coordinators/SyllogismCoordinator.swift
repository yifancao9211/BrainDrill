import Foundation
import Observation

@Observable
final class SyllogismCoordinator {
    var engine: SyllogismEngine?
    var statusMessage: String = "逻辑快判：限时判断推理是否有效。"
    var lastResult: SessionResult?

    var isActive: Bool { engine != nil && !(engine?.isComplete ?? true) }

    private(set) var sessionConditions = SessionConditions()
    private(set) var sessionsCompleted: Int = 0

    // MARK: - Learning State

    enum Mode: Equatable {
        case idle
        case learning(lessonGroup: Int)
        case practice(lessonGroup: Int)
        case training
    }

    var mode: Mode = .idle

    /// Completed lesson groups (persisted via UserDefaults)
    var completedLessons: Set<Int> {
        get {
            let arr = UserDefaults.standard.array(forKey: "syllogism_completed_lessons") as? [Int] ?? []
            return Set(arr)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "syllogism_completed_lessons")
        }
    }

    /// Per-type accuracy stats (persisted via UserDefaults)
    var typeStats: [String: SyllogismTypeStats] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "syllogism_type_stats"),
                  let decoded = try? JSONDecoder().decode([String: SyllogismTypeStats].self, from: data) else {
                return [:]
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "syllogism_type_stats")
            }
        }
    }

    // MARK: - Learning

    func hasCompletedLearning(for difficulty: Int) -> Bool {
        let required: [Int]
        switch difficulty {
        case 1: required = [1, 2, 3, 4]
        case 2: required = [5, 6, 7, 8, 9]
        case 3: required = [10, 11, 12, 13]
        default: required = []
        }
        return required.allSatisfy { completedLessons.contains($0) }
    }

    func isLessonUnlocked(_ lessonGroup: Int) -> Bool {
        let prereqs = SyllogismLessonBank.requiredCompletedLessons(for: lessonGroup)
        return prereqs.allSatisfy { completedLessons.contains($0) }
    }

    func markLessonCompleted(_ lessonGroup: Int) {
        var completed = completedLessons
        completed.insert(lessonGroup)
        completedLessons = completed
    }

    func startLearning(lessonGroup: Int) {
        mode = .learning(lessonGroup: lessonGroup)
        statusMessage = "学习第\(lessonGroup)课"
    }

    // MARK: - Practice

    var practiceEngine: SyllogismEngine?
    var practiceResults: [SyllogismTrialResult] = []

    func startPractice(lessonGroup: Int) {
        let types = SyllogismType.typesInLesson(lessonGroup)
        let lesson = SyllogismLessonBank.lesson(lessonGroup)
        practiceEngine = SyllogismEngine(difficulty: lesson.difficulty, totalTrials: min(5, max(3, types.count * 2)))
        practiceResults = []
        mode = .practice(lessonGroup: lessonGroup)
        statusMessage = "引导练习 — 不限时间，认真思考"
    }

    // MARK: - Training

    func startSession(adaptiveState: ModuleAdaptiveState) {
        let difficulty = adaptiveState.recommendedStartLevel
        let eng = SyllogismEngine(difficulty: difficulty)

        // Apply weak-type weights for spaced repetition
        var weights: [SyllogismType: Double] = [:]
        let stats = typeStats
        for type in SyllogismType.available(for: difficulty) {
            if let stat = stats[type.rawValue], stat.isWeak {
                weights[type] = 2.0  // 2x probability for weak types
            }
        }
        eng.weakTypeWeights = weights

        engine = eng
        lastResult = nil
        sessionConditions = SessionConditions(
            feedbackEnabled: true,
            adaptiveEnabled: true,
            customParameters: [
                "startingLevel": "\(difficulty)"
            ]
        )
        mode = .training
        statusMessage = "判断推理是否有效，注意时间限制"
    }

    func handleResponse(userSaysValid: Bool, at date: Date = Date()) {
        engine?.recordResponse(userSaysValid: userSaysValid, at: date)
    }

    func handleTimeout() {
        engine?.recordTimeout()
    }

    func advanceToNext() {
        engine?.advanceToNext()
    }

    func finalizeIfComplete() -> SessionResult? {
        guard let engine, engine.isComplete else { return nil }
        return buildResult()
    }

    func cancelSession() {
        engine = nil
        practiceEngine = nil
        mode = .idle
        statusMessage = "已取消逻辑快判训练。"
    }

    // MARK: - Stats Update

    func updateTypeStats(from results: [SyllogismTrialResult]) {
        var stats = typeStats
        for result in results {
            let key = result.trial.type.rawValue
            var stat = stats[key] ?? SyllogismTypeStats()
            stat.record(correct: result.isCorrect)
            stats[key] = stat
        }
        typeStats = stats
    }

    /// Returns weak types for the given difficulty
    func weakTypes(for difficulty: Int) -> [SyllogismType] {
        let stats = typeStats
        return SyllogismType.available(for: difficulty).filter { type in
            stats[type.rawValue]?.isWeak == true
        }
    }

    // MARK: - Private

    private func buildResult() -> SessionResult? {
        guard let engine else { return nil }
        let metrics = engine.computeMetrics()
        let now = Date()

        var conditions = sessionConditions
        conditions.customParameters["finalLevel"] = "\(engine.difficulty)"
        conditions.customParameters["recommendedStartLevel"] = "\(engine.difficulty)"

        let result = SessionResult(
            module: .syllogism,
            startedAt: engine.startedAt,
            endedAt: now,
            duration: now.timeIntervalSince(engine.startedAt),
            metrics: .syllogism(metrics),
            conditions: conditions
        )
        lastResult = result
        sessionsCompleted += 1

        // Update per-type stats
        updateTypeStats(from: engine.trialResults)

        statusMessage = "逻辑快判完成 — 准确率 \(String(format: "%.0f", metrics.accuracy * 100))%  d'=\(String(format: "%.1f", metrics.dPrime))"
        self.engine = nil
        mode = .idle
        return result
    }
}
