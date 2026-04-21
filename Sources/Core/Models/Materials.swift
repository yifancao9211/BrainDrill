import Foundation
import os

enum ContentDirectoryKind: String, Codable, CaseIterable, Identifiable {
    case partyStateStudy
    case disciplineLibrary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .partyStateStudy:
            "党政学习"
        case .disciplineLibrary:
            "学科资料库"
        }
    }

    var subtitle: String {
        switch self {
        case .partyStateStudy:
            "党史党建、理论路线、国家制度、政策法治与公开学习资料"
        case .disciplineLibrary:
            "自然科学、应用科学、社会科学、人文学科与交叉学科"
        }
    }
}

enum DisciplineGroup: String, Codable, CaseIterable, Identifiable {
    case naturalSciences
    case appliedSciences
    case socialSciences
    case humanities
    case interdisciplinaryStudies
    case fundamentalSciences

    var id: String { rawValue }

    var title: String {
        switch self {
        case .naturalSciences:
            "自然科学"
        case .appliedSciences:
            "应用科学"
        case .socialSciences:
            "社会科学"
        case .humanities:
            "人文学科"
        case .interdisciplinaryStudies:
            "交叉学科"
        case .fundamentalSciences:
            "基础学科"
        }
    }
}

enum SubdisciplineKind: String, Codable, CaseIterable, Identifiable {
    case physics
    case chemistry
    case biology
    case earthScience
    case astronomy
    case engineering
    case computerScience
    case medicine
    case psychology
    case sociology
    case economics
    case politicalScience
    case anthropology
    case law
    case philosophy
    case history
    case linguistics
    case environmentalScience
    case bioinformatics
    case neuroscience
    case fundamentalSciences

    var id: String { rawValue }

    var title: String {
        switch self {
        case .physics:
            "物理学"
        case .chemistry:
            "化学"
        case .biology:
            "生物学"
        case .earthScience:
            "地球科学"
        case .astronomy:
            "天文学"
        case .engineering:
            "工程学"
        case .computerScience:
            "计算机科学"
        case .medicine:
            "医学"
        case .psychology:
            "心理学"
        case .sociology:
            "社会学"
        case .economics:
            "经济学"
        case .politicalScience:
            "政治学"
        case .anthropology:
            "人类学"
        case .law:
            "法学"
        case .philosophy:
            "哲学"
        case .history:
            "历史学"
        case .linguistics:
            "语言学"
        case .environmentalScience:
            "环境科学"
        case .bioinformatics:
            "生物信息学"
        case .neuroscience:
            "神经科学"
        case .fundamentalSciences:
            "基础学科"
        }
    }

    var group: DisciplineGroup {
        switch self {
        case .physics, .chemistry, .biology, .earthScience, .astronomy:
            .naturalSciences
        case .engineering, .computerScience, .medicine:
            .appliedSciences
        case .psychology, .sociology, .economics, .politicalScience, .anthropology, .law:
            .socialSciences
        case .philosophy, .history, .linguistics:
            .humanities
        case .environmentalScience, .bioinformatics, .neuroscience:
            .interdisciplinaryStudies
        case .fundamentalSciences:
            .fundamentalSciences
        }
    }
}

enum SourceHealthStatus: String, Codable, CaseIterable {
    case idle
    case healthy
    case timeout
    case networkError
    case parseFailure
    case emptyContent
    case protectedSource
    case httpError

    var label: String {
        switch self {
        case .idle:
            "未运行"
        case .healthy:
            "正常"
        case .timeout:
            "超时"
        case .networkError:
            "网络失败"
        case .parseFailure:
            "解析失败"
        case .emptyContent:
            "空内容"
        case .protectedSource:
            "受保护来源"
        case .httpError:
            "HTTP 错误"
        }
    }
}

enum SourceCadence: String, Codable {
    case timely
    case evergreen
    case protectedAttempt

    var label: String {
        switch self {
        case .timely:
            "较新源"
        case .evergreen:
            "常青源"
        case .protectedAttempt:
            "可尝试源"
        }
    }
}

enum ConcreteSourceKind: String, Codable, CaseIterable, Identifiable {
    case qstheory
    case cpc12371
    case ccps
    case studyTimes
    case govCnPolicy
    case npcLaw
    case peopleTheory
    case xinhuaPolitics
    case openStax
    case wikibooks
    case mitOpenCourseware
    case libreTexts
    case ourWorldInData
    case worldBank
    case unesco
    case nasa
    case cdc
    case nih
    case brainFacts
    case lawCornell
    case oecd

    var id: String { rawValue }

    var title: String {
        switch self {
        case .qstheory:
            "求是网"
        case .cpc12371:
            "共产党员网"
        case .ccps:
            "中共中央党校"
        case .studyTimes:
            "学习时报"
        case .govCnPolicy:
            "中国政府网"
        case .npcLaw:
            "全国人大网"
        case .peopleTheory:
            "人民网理论"
        case .xinhuaPolitics:
            "新华网时政"
        case .openStax:
            "OpenStax"
        case .wikibooks:
            "Wikibooks"
        case .mitOpenCourseware:
            "MIT OpenCourseWare"
        case .libreTexts:
            "LibreTexts"
        case .ourWorldInData:
            "Our World in Data"
        case .worldBank:
            "World Bank"
        case .unesco:
            "UNESCO"
        case .nasa:
            "NASA"
        case .cdc:
            "CDC"
        case .nih:
            "NIH"
        case .brainFacts:
            "BrainFacts"
        case .lawCornell:
            "Cornell LII"
        case .oecd:
            "OECD"
        }
    }

    var subtitle: String {
        switch self {
        case .qstheory:
            "理论路线与党政学习材料"
        case .cpc12371:
            "党员教育与党建公开资料"
        case .ccps:
            "党校公开文章与学习材料"
        case .studyTimes:
            "党校报刊与理论学习材料"
        case .govCnPolicy:
            "国家政策与制度解读"
        case .npcLaw:
            "法律制度与立法公开资料"
        case .peopleTheory:
            "理论、党建与制度学习栏目"
        case .xinhuaPolitics:
            "时政、制度与治理公开报道"
        case .openStax:
            "开放教材与系统入门内容"
        case .wikibooks:
            "开放教材与基础概念材料"
        case .mitOpenCourseware:
            "大学公开课程与导读页"
        case .libreTexts:
            "开放教材与学科知识页"
        case .ourWorldInData:
            "社会、经济与全球数据解读"
        case .worldBank:
            "发展经济与公共政策资料"
        case .unesco:
            "教育、文化与社会发展公开页"
        case .nasa:
            "自然科学与工程科普"
        case .cdc:
            "公共卫生与医学科普"
        case .nih:
            "医学、生物与健康研究公开页"
        case .brainFacts:
            "脑科学与心理认知科普"
        case .lawCornell:
            "法学与法律概念解释"
        case .oecd:
            "政策研究与国际社会数据"
        }
    }

    var directory: ContentDirectoryKind {
        switch self {
        case .qstheory, .cpc12371, .ccps, .studyTimes, .govCnPolicy, .npcLaw, .peopleTheory, .xinhuaPolitics:
            .partyStateStudy
        case .openStax, .wikibooks, .mitOpenCourseware, .libreTexts, .ourWorldInData, .worldBank, .unesco, .nasa, .cdc, .nih, .brainFacts, .lawCornell, .oecd:
            .disciplineLibrary
        }
    }

    var sourceDomainLabel: String {
        switch self {
        case .qstheory, .cpc12371, .ccps, .studyTimes, .peopleTheory, .xinhuaPolitics:
            "党政学习"
        case .govCnPolicy, .npcLaw, .lawCornell:
            "法政制度"
        case .openStax, .wikibooks, .mitOpenCourseware, .libreTexts:
            "教材课程"
        case .ourWorldInData, .worldBank, .unesco, .oecd:
            "社会数据"
        case .nasa:
            "科学机构"
        case .cdc, .nih:
            "公共卫生"
        case .brainFacts:
            "脑科学"
        }
    }

    var cadence: SourceCadence {
        switch self {
        case .openStax, .wikibooks, .mitOpenCourseware, .libreTexts, .lawCornell:
            .evergreen
        case .oecd, .worldBank, .unesco:
            .protectedAttempt
        default:
            .timely
        }
    }

    var primaryGroup: DisciplineGroup? {
        switch self {
        case .qstheory, .cpc12371, .ccps, .studyTimes, .govCnPolicy, .npcLaw, .peopleTheory, .xinhuaPolitics:
            nil
        case .openStax, .wikibooks, .mitOpenCourseware, .libreTexts:
            .fundamentalSciences
        case .ourWorldInData, .worldBank, .unesco, .oecd:
            .socialSciences
        case .nasa:
            .naturalSciences
        case .cdc, .nih:
            .appliedSciences
        case .brainFacts:
            .interdisciplinaryStudies
        case .lawCornell:
            .socialSciences
        }
    }

    var disciplineTags: [SubdisciplineKind] {
        switch self {
        case .qstheory:
            [.politicalScience, .philosophy, .history]
        case .cpc12371:
            [.politicalScience, .history, .sociology]
        case .ccps:
            [.politicalScience, .law, .sociology]
        case .studyTimes:
            [.politicalScience, .history, .philosophy]
        case .govCnPolicy:
            [.politicalScience, .law, .economics]
        case .npcLaw:
            [.law, .politicalScience, .history]
        case .peopleTheory:
            [.politicalScience, .philosophy, .history, .sociology]
        case .xinhuaPolitics:
            [.politicalScience, .history, .economics]
        case .openStax:
            [.physics, .chemistry, .biology, .astronomy, .engineering, .computerScience, .fundamentalSciences]
        case .wikibooks:
            [.physics, .chemistry, .biology, .astronomy, .computerScience, .linguistics, .fundamentalSciences]
        case .mitOpenCourseware:
            [.physics, .chemistry, .biology, .engineering, .computerScience, .philosophy, .bioinformatics, .neuroscience]
        case .libreTexts:
            [.physics, .chemistry, .biology, .engineering, .computerScience, .bioinformatics, .fundamentalSciences]
        case .ourWorldInData:
            [.economics, .sociology, .politicalScience, .environmentalScience, .psychology]
        case .worldBank:
            [.economics, .sociology, .politicalScience, .environmentalScience]
        case .unesco:
            [.sociology, .anthropology, .history, .linguistics, .environmentalScience, .medicine]
        case .nasa:
            [.physics, .earthScience, .astronomy, .engineering, .environmentalScience]
        case .cdc:
            [.medicine, .biology, .environmentalScience, .neuroscience]
        case .nih:
            [.medicine, .biology, .psychology, .bioinformatics, .neuroscience]
        case .brainFacts:
            [.psychology, .biology, .medicine, .neuroscience]
        case .lawCornell:
            [.law, .politicalScience, .philosophy]
        case .oecd:
            [.economics, .sociology, .politicalScience]
        }
    }

    var iconName: String {
        switch self.directory {
        case .partyStateStudy:
            "building.columns.circle.fill"
        case .disciplineLibrary:
            switch self {
            case .nasa:
                "sparkles"
            case .cdc, .nih:
                "cross.case.fill"
            case .ourWorldInData, .worldBank, .unesco, .oecd:
                "chart.bar.xaxis"
            case .brainFacts:
                "brain.head.profile"
            case .lawCornell:
                "scale.3d"
            default:
                "book.closed.fill"
            }
        }
    }

    var seedURL: URL {
        switch self {
        case .qstheory:
            URL(string: "https://www.qstheory.cn/qswp.htm")!
        case .cpc12371:
            URL(string: "https://www.12371.cn/zxfb/")!
        case .ccps:
            URL(string: "https://www.ccps.gov.cn/xwpd/rdxw/")!
        case .studyTimes:
            URL(string: "https://www.studytimes.cn/llsd/")!
        case .govCnPolicy:
            URL(string: "https://www.gov.cn/zhengce/jiedu/index.htm")!
        case .npcLaw:
            URL(string: "http://www.npc.gov.cn/npc/c2/kgfb/")!
        case .peopleTheory:
            URL(string: "https://theory.people.com.cn/")!
        case .xinhuaPolitics:
            URL(string: "https://www.news.cn/politics/")!
        case .openStax:
            URL(string: "https://openstax.org/subjects")!
        case .wikibooks:
            URL(string: "https://en.wikibooks.org/wiki/Wikibooks:All_books")!
        case .mitOpenCourseware:
            URL(string: "https://ocw.mit.edu/")!
        case .libreTexts:
            URL(string: "https://chem.libretexts.org/")!
        case .ourWorldInData:
            URL(string: "https://ourworldindata.org/feed")!
        case .worldBank:
            URL(string: "https://www.worldbank.org/en/news/all")!
        case .unesco:
            URL(string: "https://www.unesco.org/en/articles")!
        case .nasa:
            URL(string: "https://www.nasa.gov/feed/")!
        case .cdc:
            URL(string: "https://www.cdc.gov/media/releases/index.html")!
        case .nih:
            URL(string: "https://www.nih.gov/news-events/news-releases")!
        case .brainFacts:
            URL(string: "https://www.brainfacts.org/")!
        case .lawCornell:
            URL(string: "https://www.law.cornell.edu/wex")!
        case .oecd:
            URL(string: "https://www.oecd.org/en/latest-news.html")!
        }
    }

    var defaultEnabled: Bool {
        switch self {
        case .worldBank, .oecd, .studyTimes, .ccps, .unesco, .wikibooks:
            false
        default:
            true
        }
    }

    var discoveryPatterns: [String] {
        switch self {
        case .ourWorldInData:
            [#"https://ourworldindata\.org/[^"'# >]+"#]
        case .nasa:
            [#"https://www\.nasa\.gov/[^"'# >]+"#]
        case .cdc:
            [#"https://www\.cdc\.gov/[^"'# >]+\.html"#]
        case .govCnPolicy:
            [#"https://www\.gov\.cn/(?:zhengce|yaowen|home)/[^"'# >]+content_\d+\.htm"#]
        case .qstheory:
            [#"https://www\.qstheory\.cn/[^"'# >]+\.htm"#]
        case .cpc12371:
            [#"https://www\.12371\.cn/\d{4}/\d{2}/\d{2}/ARTI\d+\.shtml"#]
        case .ccps:
            [#"https://www\.ccps\.gov\.cn/[^"'# >]+/t\d{8}_\d+\.shtml"#]
        case .studyTimes:
            [#"https://www\.studytimes\.cn/[^"'# >]+/\d{6}/t\d{8}_\d+\.html"#, #"https://paper\.studytimes\.cn/[^"'# >]+/content_\d+\.htm"#]
        case .npcLaw:
            [#"https?://www\.npc\.gov\.cn/npc/[^"'# >]+\.html"#]
        case .peopleTheory:
            [
                #"https?://(?:theory|cpc|dangjian)\.people\.com\.cn/n1/\d{4}/\d{4}/c\d+-\d+\.html"#,
                #"http://(?:theory|cpc|dangjian)\.people\.com\.cn/n/\d{4}/\d{4}/c\d+-\d+\.html"#
            ]
        case .xinhuaPolitics:
            [#"https?://(?:www\.)?news\.cn/[^"'# >]+/c\.html"#, #"https?://(?:www\.)?news\.cn/[^"'# >]+\.html"#]
        case .openStax:
            [#"https://openstax\.org/books/[^"'# >]+/pages/[^"'# >]+"#]
        case .wikibooks:
            [#"https://en\.wikibooks\.org/wiki/[^:#?"' >]+"#]
        case .mitOpenCourseware:
            [#"https://ocw\.mit\.edu/courses/[^"'# >]+/?$"#]
        case .libreTexts:
            [#"https://[^\"']+\.libretexts\.org/[^\"']+"#]
        case .worldBank:
            [#"https://www\.worldbank\.org/en/(?:news/press-release|news/feature-story|news/statement|news/speech|events)/[^"'# >]+"#]
        case .unesco:
            [#"https://www\.unesco\.org/en/articles/[^"'# >]+"#, #"https://www\.unesco\.org/en/[^"'# >]+"#]
        case .nih:
            [#"https://www\.nih\.gov/news-events/(?:news-releases|nih-research-matters)/[^"'# >]+"#]
        case .brainFacts:
            [#"https://www\.brainfacts\.org/[^"'# >]+/[^"'# >]+(?:/[^"'# >]+)?$"#]
        case .lawCornell:
            [#"https://www\.law\.cornell\.edu/wex/[^/#?"' >]+"#]
        case .oecd:
            [#"https://www\.oecd\.org/en/[^"'# >]+\.html"#]
        }
    }

    func acceptsCandidateURL(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        switch self {
        case .cpc12371:
            return path.hasSuffix(".shtml") && path.contains("/20")
        case .ccps:
            return path.hasSuffix(".shtml") && path.contains("/t20")
        case .studyTimes:
            return path.hasSuffix(".html") && path.contains("/t20")
        case .govCnPolicy:
            return path.hasSuffix(".htm") && path.contains("content_")
        case .peopleTheory:
            return path.hasSuffix(".html") && (path.contains("/n1/") || path.contains("/n/"))
        case .xinhuaPolitics:
            return path.hasSuffix(".html") || path.hasSuffix("/c.html")
        case .openStax:
            return path.contains("/books/") && path.contains("/pages/")
        case .wikibooks:
            let lastComponent = url.lastPathComponent.lowercased()
            return !lastComponent.isEmpty && !lastComponent.contains(":") && lastComponent != "main_page"
        case .mitOpenCourseware:
            return path.hasPrefix("/courses/") && path != "/courses/"
        case .libreTexts:
            return !path.contains("/home") && !path.contains("/courses") && !path.contains("/bookshelves")
        case .worldBank:
            return path.contains("/en/news/")
        case .unesco:
            return path.contains("/en/articles/")
        case .nasa:
            return path != "/" && !path.hasPrefix("/feed")
        case .cdc:
            return path.hasSuffix(".html") && !path.contains("/index.html")
        case .nih:
            return path.contains("/news-events/") && !path.hasSuffix("/news-releases")
        case .brainFacts:
            return path.split(separator: "/").count >= 3 && !path.hasSuffix("/thinking-sensing-and-behaving")
        case .lawCornell:
            return path.hasPrefix("/wex/") && path != "/wex"
        case .qstheory, .npcLaw, .oecd, .ourWorldInData:
            return true
        }
    }

}

struct ContentSourceConfig: Codable, Equatable, Identifiable {
    var kind: ConcreteSourceKind
    var isEnabled: Bool
    var lastCompletedAt: Date?
    var lastError: String?
    var lastStatus: SourceHealthStatus?
    var consecutiveFailures: Int
    var lastAutoDisabledAt: Date?

    var id: String { kind.id }

    init(kind: ConcreteSourceKind, isEnabled: Bool, lastCompletedAt: Date? = nil, lastError: String? = nil, lastStatus: SourceHealthStatus? = nil, consecutiveFailures: Int = 0, lastAutoDisabledAt: Date? = nil) {
        self.kind = kind
        self.isEnabled = isEnabled
        self.lastCompletedAt = lastCompletedAt
        self.lastError = lastError
        self.lastStatus = lastStatus
        self.consecutiveFailures = consecutiveFailures
        self.lastAutoDisabledAt = lastAutoDisabledAt
    }

    /// Auto-disable after 3 consecutive failures
    mutating func recordFailure() {
        consecutiveFailures += 1
        if consecutiveFailures >= 3 && isEnabled {
            isEnabled = false
            lastAutoDisabledAt = Date()
        }
    }

    mutating func recordSuccess() {
        consecutiveFailures = 0
    }

    static let defaults = ConcreteSourceKind.allCases.map {
        ContentSourceConfig(kind: $0, isEnabled: $0.defaultEnabled)
    }
}

struct SourceArticle: Codable, Equatable, Identifiable {
    var id: String
    var sourceKind: ConcreteSourceKind
    var title: String
    var url: String
    var summary: String
    var excerpt: String
    var sourceText: String?
    var publishedAt: Date?
    var fetchedAt: Date
    var author: String?
    var domainTag: String

    init(
        id: String? = nil,
        sourceKind: ConcreteSourceKind,
        title: String,
        url: String,
        summary: String,
        excerpt: String,
        sourceText: String? = nil,
        publishedAt: Date? = nil,
        fetchedAt: Date = Date(),
        author: String? = nil,
        domainTag: String? = nil
    ) {
        self.sourceKind = sourceKind
        self.title = title
        self.url = url
        self.summary = summary
        self.excerpt = excerpt
        self.sourceText = sourceText
        self.publishedAt = publishedAt
        self.fetchedAt = fetchedAt
        self.author = author
        self.domainTag = domainTag ?? sourceKind.sourceDomainLabel
        self.id = id ?? StableMaterialID.make(prefix: sourceKind.rawValue, seed: url)
    }

    var aiInputText: String {
        let text = sourceText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !text.isEmpty {
            return text
        }
        return excerpt
    }
}

enum MaterialCandidateStatus: String, Codable, CaseIterable {
    case pending
    case rejected
    case approved

    var label: String {
        switch self {
        case .pending:
            "待审核"
        case .rejected:
            "已退回"
        case .approved:
            "已入库"
        }
    }
}

struct MaterialCandidate: Codable, Equatable, Identifiable {
    var id: String
    var sourceArticle: SourceArticle
    var generatedPassage: ReadingPassage?
    var localizedTitle: String?
    var generatedSummary: String
    var score: Double
    var ruleScore: Double
    var aiScore: Double
    var suggestedDifficulty: Int
    var status: MaterialCandidateStatus
    var failureReasons: [String]
    var debugLogs: [String]?
    var cleaningModel: String
    var generatedAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        sourceArticle: SourceArticle,
        generatedPassage: ReadingPassage?,
        localizedTitle: String? = nil,
        generatedSummary: String,
        score: Double,
        ruleScore: Double,
        aiScore: Double,
        suggestedDifficulty: Int,
        status: MaterialCandidateStatus = .pending,
        failureReasons: [String] = [],
        debugLogs: [String]? = nil,
        cleaningModel: String,
        generatedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceArticle = sourceArticle
        self.generatedPassage = generatedPassage
        self.localizedTitle = localizedTitle
        self.generatedSummary = generatedSummary
        self.score = score
        self.ruleScore = ruleScore
        self.aiScore = aiScore
        self.suggestedDifficulty = suggestedDifficulty
        self.status = status
        self.failureReasons = failureReasons
        self.debugLogs = debugLogs
        self.cleaningModel = cleaningModel
        self.generatedAt = generatedAt
        self.updatedAt = updatedAt
    }

    var canApprove: Bool {
        status == .pending && score >= 70 && failureReasons.isEmpty && generatedPassage != nil
    }

    var displayTitle: String {
        if let title = generatedPassage?.title.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        if let title = localizedTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        return sourceArticle.title
    }

    var displaySummary: String {
        if let body = generatedPassage?.body.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
            return String(body.prefix(1_200))
        }
        let summary = generatedSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !summary.isEmpty {
            return String(summary.prefix(1_200))
        }
        return String(sourceArticle.excerpt.prefix(1_200))
    }

    var resolvedDebugLogs: [String] {
        debugLogs ?? []
    }
}

struct ApprovedReadingPassage: Codable, Equatable, Identifiable {
    var id: String { passage.id }
    var passage: ReadingPassage
    var sourceArticle: SourceArticle
    var approvedAt: Date
    var candidateID: String
    var score: Double
}

struct MaterialSourceRunSummary: Codable, Equatable, Identifiable {
    var id: String { sourceKind.id }
    var sourceKind: ConcreteSourceKind
    var articleCount: Int
    var candidateCount: Int
    var detailMessage: String?
    var errorMessage: String?
    var status: SourceHealthStatus?
}

struct MaterialRunRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    var articleCount: Int
    var candidateCount: Int
    var errorMessages: [String]
    var sourceSummaries: [MaterialSourceRunSummary]

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        articleCount: Int,
        candidateCount: Int,
        errorMessages: [String],
        sourceSummaries: [MaterialSourceRunSummary]
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.articleCount = articleCount
        self.candidateCount = candidateCount
        self.errorMessages = errorMessages
        self.sourceSummaries = sourceSummaries
    }
}

enum ReadingPassageRepository {
    private static let lock = OSAllocatedUnfairLock(initialState: [ApprovedReadingPassage]())

    static func updateApprovedPassages(_ passages: [ApprovedReadingPassage]) {
        lock.withLock { $0 = passages }
    }

    static func approvedPassages() -> [ApprovedReadingPassage] {
        lock.withLock { $0 }
    }

    static func mergedPassages(bundled: [ReadingPassage]) -> [ReadingPassage] {
        let approved = lock.withLock { $0 }
        var combined = Dictionary(uniqueKeysWithValues: bundled.map { ($0.id, $0) })
        for item in approved {
            combined[item.passage.id] = item.passage
        }
        return combined.values.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }
}

enum StableMaterialID {
    static func make(prefix: String, seed: String) -> String {
        let normalized = seed.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in normalized.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return "\(prefix)-\(String(hash, radix: 16))"
    }
}

extension ReadingPassage {
    var validationIssues: [String] {
        var issues: [String] = []

        if mainIdeaOptions.count != 4 {
            issues.append("主旨选项必须正好 4 个。")
        }
        if !mainIdeaOptions.indices.contains(mainIdeaAnswerIndex) {
            issues.append("主旨正确答案索引无效。")
        }
        if claimAnchors.isEmpty {
            issues.append("至少需要 1 条结论锚点。")
        }
        if evidenceItems.count < 4 {
            issues.append("证据分类项至少需要 4 条。")
        }
        if recallPrompts.count < 5 {
            issues.append("延迟回忆提示至少需要 5 条。")
        }
        if recallKeywords.count < 5 {
            issues.append("延迟回忆关键词至少需要 5 个。")
        }
        if !(1...3).contains(difficulty) {
            issues.append("难度必须在 1 到 3 之间。")
        }

        let claimIDs = Set(claimAnchors.map(\.id))
        for item in evidenceItems {
            if let supportsClaimID = item.supportsClaimID, !claimIDs.contains(supportsClaimID) {
                issues.append("证据项 \(item.id) 的 supportsClaimID 未匹配任何结论。")
            }
        }

        return issues
    }
}
