import Foundation

enum ReadingStructureType: String, Codable, CaseIterable, Identifiable {
    case causeEffect
    case compareContrast
    case problemSolution
    case mechanism

    var id: String { rawValue }

    var label: String {
        switch self {
        case .causeEffect:
            "因果"
        case .compareContrast:
            "对比"
        case .problemSolution:
            "问题-解决"
        case .mechanism:
            "机制说明"
        }
    }
}

struct MainIdeaRubric: Codable, Equatable {
    let idealSummary: String
    let keywords: [String]
    let trapNote: String
}

struct ReadingClaimAnchor: Codable, Identifiable, Equatable {
    enum Scope: String, Codable, CaseIterable, Identifiable {
        case global
        case local

        var id: String { rawValue }

        var label: String {
            switch self {
            case .global:
                "总论点"
            case .local:
                "局部结论"
            }
        }
    }

    let id: String
    let text: String
    let scope: Scope
}

struct EvidenceClassificationItem: Codable, Identifiable, Equatable {
    enum Role: String, Codable, CaseIterable, Identifiable {
        case claim
        case evidence
        case background
        case limitation

        var id: String { rawValue }

        var label: String {
            switch self {
            case .claim:      "结论"
            case .evidence:   "证据"
            case .background: "背景"
            case .limitation: "限制"
            }
        }
    }

    let id: String
    let text: String
    let role: Role
    let supportsClaimID: String?
}

struct DelayedRecallPrompt: Codable, Identifiable, Equatable {
    let id: String
    let text: String
    let isTarget: Bool
}

struct ReadingPassage: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let domainTag: String
    let difficulty: Int
    let structureType: ReadingStructureType
    let body: String
    let mainIdeaOptions: [String]
    let mainIdeaAnswerIndex: Int
    let mainIdeaRubric: MainIdeaRubric
    let claimAnchors: [ReadingClaimAnchor]
    let evidenceItems: [EvidenceClassificationItem]
    let recallPrompts: [DelayedRecallPrompt]
    let recallKeywords: [String]

    var mainIdeaMinimumLength: Int {
        switch difficulty {
        case 1:
            10
        case 2:
            14
        default:
            18
        }
    }

    var requiresClaimMapping: Bool { difficulty >= 2 }

    var mapsLimitationsToClaims: Bool { difficulty >= 3 }

    var recallDelaySeconds: Int {
        switch difficulty {
        case 1:
            20
        case 2:
            45
        default:
            75
        }
    }

    var distractorQuestionCount: Int {
        switch difficulty {
        case 1:
            2
        case 2:
            3
        default:
            4
        }
    }

    var freeRecallMinimumLength: Int {
        switch difficulty {
        case 1:
            8
        case 2:
            12
        default:
            16
        }
    }

    var evidenceItemsNeedingMapping: [EvidenceClassificationItem] {
        evidenceItems.filter {
            guard $0.supportsClaimID != nil else { return false }
            switch $0.role {
            case .evidence:
                return true
            case .limitation:
                return mapsLimitationsToClaims
            case .claim, .background:
                return false
            }
        }
    }
}

enum ReadingDifficultyPlanner {
    static func nextDifficulty(for module: TrainingModule, sessions: [SessionResult]) -> Int {
        let recent = recentSessions(for: module, sessions: sessions)
        guard let currentDifficulty = recent.first.map(readingDifficulty(for:)) else { return 1 }

        let scores = recent.map(score(for:))
        let recommendation = WindowedAdaptiveEvaluator.evaluate(
            recentScores: scores,
            config: .reading
        )

        switch recommendation {
        case .promote:
            return min(currentDifficulty + 1, 3)
        case .demote:
            return max(currentDifficulty - 1, 1)
        case .stay:
            // Fallback for small window (< 5 sessions): use old simple average
            if recent.count >= 1 {
                let avg = scores.reduce(0, +) / Double(scores.count)
                if avg >= 0.82 { return min(currentDifficulty + 1, 3) }
                if avg <= 0.55 { return max(currentDifficulty - 1, 1) }
            }
            return currentDifficulty
        }
    }

    static func nextPassage(for module: TrainingModule, sessions: [SessionResult]) -> ReadingPassage {
        let targetDifficulty = nextDifficulty(for: module, sessions: sessions)
        let recent = recentSessions(for: module, sessions: sessions)
        let lastPassageID = recent.first.flatMap(passageID(for:))

        let exactMatches = ReadingPassageLibrary.all.filter { $0.difficulty == targetDifficulty && $0.id != lastPassageID }
        if let selected = exactMatches.randomElement() {
            return selected
        }

        let fallbackExactMatches = ReadingPassageLibrary.all.filter { $0.difficulty == targetDifficulty }
        if let selected = fallbackExactMatches.randomElement() {
            return selected
        }

        return ReadingPassageLibrary.all.min(by: {
            abs($0.difficulty - targetDifficulty) < abs($1.difficulty - targetDifficulty)
        }) ?? ReadingPassageLibrary.all[0]
    }

    private static func recentSessions(for module: TrainingModule, sessions: [SessionResult]) -> [SessionResult] {
        sessions
            .filter { $0.module == module }
            .sorted { $0.endedAt > $1.endedAt }
            .prefix(5)
            .map { $0 }
    }

    private static func readingDifficulty(for session: SessionResult) -> Int {
        switch session.metrics {
        case let .mainIdea(metrics):
            metrics.difficulty
        case let .evidenceMap(metrics):
            metrics.difficulty
        case let .delayedRecall(metrics):
            metrics.difficulty
        default:
            1
        }
    }

    private static func passageID(for session: SessionResult) -> String? {
        switch session.metrics {
        case let .mainIdea(metrics):
            metrics.passageID
        case let .evidenceMap(metrics):
            metrics.passageID
        case let .delayedRecall(metrics):
            metrics.passageID
        default:
            nil
        }
    }

    private static func score(for session: SessionResult) -> Double {
        switch session.metrics {
        case let .mainIdea(metrics):
            let optionScore = metrics.isCorrect ? 1.0 : 0.0
            let generationScore = metrics.keywordCoverage
            return (optionScore * 0.55) + (generationScore * 0.45)
        case let .evidenceMap(metrics):
            return (metrics.accuracy * 0.6) + (metrics.mappingAccuracy * 0.4)
        case let .delayedRecall(metrics):
            let unguidedScore = metrics.freeRecallCoverage
            return (metrics.accuracy * 0.55) + (unguidedScore * 0.45)
        default:
            return 0.5
        }
    }
}

enum ReadingPassageLibrary {
    private static let bundled: [ReadingPassage] = loadPassages()

    static var all: [ReadingPassage] {
        ReadingPassageRepository.mergedPassages(bundled: bundled)
    }

    static func randomPassage(maxDifficulty: Int? = nil) -> ReadingPassage {
        let candidates = maxDifficulty.map { limit in
            all.filter { $0.difficulty <= limit }
        } ?? all
        return candidates.randomElement() ?? all[0]
    }

    private static func loadPassages() -> [ReadingPassage] {
        guard let resourceURL = locateResource(named: "reading_passages", extension: "json") else {
            preconditionFailure("Missing bundled reading_passages.json resource.")
        }

        do {
            let data = try Data(contentsOf: resourceURL)
            let passages = try JSONDecoder().decode([ReadingPassage].self, from: data)
            validate(passages)
            return passages
        } catch {
            preconditionFailure("Failed to decode reading_passages.json: \(error)")
        }
    }

    private static func validate(_ passages: [ReadingPassage]) {
        precondition(!passages.isEmpty, "Reading passage library must not be empty.")

        let ids = passages.map(\.id)
        precondition(Set(ids).count == ids.count, "Reading passage ids must be unique.")

        let supportedDifficulties = Set(passages.map(\.difficulty))
        precondition(supportedDifficulties.isSuperset(of: [1, 2, 3]), "Reading passage library must cover difficulties 1-3.")

        for passage in passages {
            precondition(passage.mainIdeaOptions.indices.contains(passage.mainIdeaAnswerIndex), "Invalid main idea answer index for \(passage.id).")
            precondition(passage.mainIdeaOptions.count == 4, "Each passage must expose exactly 4 main idea options: \(passage.id).")
            precondition(!passage.claimAnchors.isEmpty, "Each passage must contain claim anchors: \(passage.id).")
            precondition(passage.evidenceItems.count >= 4, "Each passage must contain at least 4 evidence items: \(passage.id).")
            precondition(passage.recallPrompts.count >= 5, "Each passage must contain at least 5 recall prompts: \(passage.id).")
            precondition(passage.recallKeywords.count >= 5, "Each passage must contain at least 5 recall keywords: \(passage.id).")
        }
    }

    private static func locateResource(named name: String, extension ext: String) -> URL? {
        let bundles = uniqueBundles([Bundle.main, Bundle(for: BundleMarker.self)] + Bundle.allBundles + Bundle.allFrameworks)
        let fileName = "\(name).\(ext)"

        for bundle in bundles {
            if let direct = bundle.url(forResource: name, withExtension: ext) {
                return direct
            }
            if let direct = bundle.url(forResource: name, withExtension: ext, subdirectory: "Reading") {
                return direct
            }
            if let direct = bundle.url(forResource: name, withExtension: ext, subdirectory: "Resources/Reading") {
                return direct
            }
            if let resourceURL = recursiveSearch(in: bundle.resourceURL, targetFileName: fileName) {
                return resourceURL
            }
        }

        return nil
    }

    private static func recursiveSearch(in directoryURL: URL?, targetFileName: String) -> URL? {
        guard let directoryURL else { return nil }
        let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let next = enumerator?.nextObject() as? URL {
            if next.lastPathComponent == targetFileName {
                return next
            }
        }

        return nil
    }

    private static func uniqueBundles(_ bundles: [Bundle]) -> [Bundle] {
        var seen: Set<String> = []
        return bundles.filter { bundle in
            let path = bundle.bundleURL.path
            return seen.insert(path).inserted
        }
    }

    private final class BundleMarker {}
}
