import Foundation

struct TrainingStatistics {
    let totalSessions: Int
    let readingSessionCount: Int
    let supportSessionCount: Int
    let lastReadingModuleName: String?

    private let counts: [TrainingModule: Int]

    init(sessions: [SessionResult]) {
        let visibleSessions = sessions.filter { TrainingModule.allCases.contains($0.module) }

        totalSessions = visibleSessions.count
        readingSessionCount = visibleSessions.filter { $0.module.dimension == .reading }.count
        supportSessionCount = visibleSessions.filter { $0.module.dimension != .reading }.count
        lastReadingModuleName = visibleSessions.first(where: { $0.module.dimension == .reading })?.module.shortName

        counts = visibleSessions.reduce(into: [TrainingModule: Int]()) { partial, session in
            partial[session.module, default: 0] += 1
        }
    }

    func count(for module: TrainingModule) -> Int {
        counts[module, default: 0]
    }
}
