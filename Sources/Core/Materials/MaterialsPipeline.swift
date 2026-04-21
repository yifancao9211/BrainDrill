import Foundation

struct MaterialsPipelineProgress: Sendable {
    var phase: String
    var fractionCompleted: Double
    var logMessage: String?
}

struct MaterialsPipelineOutcome {
    var candidates: [MaterialCandidate]
    var runRecord: MaterialRunRecord
    var updatedSourceConfigs: [ContentSourceConfig]
}

private struct SourceFetchOutcome {
    var articles: [SourceArticle]
    var status: SourceHealthStatus
    var detailMessage: String?
}

enum MaterialsPipelineError: LocalizedError {
    case invalidBaseURL
    case unsupportedAIResponse(logs: [String])
    case missingAIText(logs: [String])

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "AI Base URL 无效。"
        case .unsupportedAIResponse:
            "AI 返回了不兼容的响应格式。"
        case .missingAIText:
            "AI 响应中没有可解析文本。"
        }
    }

    var debugLogs: [String] {
        switch self {
        case .invalidBaseURL:
            ["AI Base URL 无效，请检查设置中的 base URL。"]
        case let .unsupportedAIResponse(logs):
            logs
        case let .missingAIText(logs):
            logs
        }
    }
}

enum SourceFetchError: LocalizedError {
    case protectedSource(message: String)
    case timeout(message: String)
    case network(message: String)
    case parseFailure(message: String)
    case emptyContent(message: String)
    case http(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case let .protectedSource(message),
            let .timeout(message),
            let .network(message),
            let .parseFailure(message),
            let .emptyContent(message),
            let .http(_, message):
            message
        }
    }

    var healthStatus: SourceHealthStatus {
        switch self {
        case .protectedSource:
            .protectedSource
        case .timeout:
            .timeout
        case .network:
            .networkError
        case .parseFailure:
            .parseFailure
        case .emptyContent:
            .emptyContent
        case .http:
            .httpError
        }
    }
}

struct MaterialsPipeline {
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func run(
        sourceConfigs: [ContentSourceConfig],
        settings: TrainingSettings,
        recentMaterialHints: [String],
        onProgress: (@Sendable (MaterialsPipelineProgress) -> Void)? = nil
    ) async -> MaterialsPipelineOutcome {
        let startedAt = Date()
        let enabledConfigs = sourceConfigs.filter(\.isEnabled)
        let articleLimit = max(1, settings.materialsAutoSourceCountPerRun)
        var sourceSummaries: [MaterialSourceRunSummary] = []
        var sourceErrors: [String] = []
        var articles: [SourceArticle] = []

        let totalSources = enabledConfigs.count
        for (configIndex, config) in enabledConfigs.enumerated() {
            onProgress?(MaterialsPipelineProgress(
                phase: "抓取文章源 (\(configIndex + 1)/\(totalSources))",
                fractionCompleted: Double(configIndex) / Double(totalSources + 1),
                logMessage: "正在访问 \(config.kind.title)..."
            ))
            if configIndex > 0 {
                try? await Task.sleep(for: .milliseconds(300))
            }
            do {
                let outcome = try await MaterialSourceCrawler(
                    sourceKind: config.kind,
                    session: urlSession
                ).fetchArticles(limit: articleLimit)
                let fetchedArticles = outcome.articles
                articles.append(contentsOf: fetchedArticles)
                sourceSummaries.append(
                    MaterialSourceRunSummary(
                        sourceKind: config.kind,
                        articleCount: fetchedArticles.count,
                        candidateCount: 0,
                        detailMessage: outcome.detailMessage,
                        errorMessage: nil,
                        status: outcome.status
                    )
                )
            } catch {
                let fetchError = (error as? SourceFetchError) ?? .network(message: error.localizedDescription)
                let message = "\(config.kind.title) 抓取失败：\(fetchError.localizedDescription)"
                sourceErrors.append(message)
                sourceSummaries.append(
                    MaterialSourceRunSummary(
                        sourceKind: config.kind,
                        articleCount: 0,
                        candidateCount: 0,
                        detailMessage: nil,
                        errorMessage: message,
                        status: fetchError.healthStatus
                    )
                )
            }
        }

        let deduplicatedArticles = Array(deduplicateArticles(articles).prefix(12))
        let cleanedCandidates = await buildCandidates(
            from: deduplicatedArticles,
            settings: settings,
            recentMaterialHints: recentMaterialHints,
            onProgress: onProgress
        )
        let candidates = cleanedCandidates.sorted { lhs, rhs in
            if lhs.status != rhs.status {
                return lhs.status.rawValue < rhs.status.rawValue
            }
            return lhs.score > rhs.score
        }

        let candidateCounts = Dictionary(grouping: candidates, by: \.sourceArticle.sourceKind).mapValues(\.count)
        let updatedSummaries = sourceSummaries.map { summary in
            var mutable = summary
            mutable.candidateCount = candidateCounts[summary.sourceKind, default: 0]
            return mutable
        }

        let updatedConfigs = sourceConfigs.map { config in
            var mutable = config
            if let summary = updatedSummaries.first(where: { $0.sourceKind == config.kind }) {
                mutable.lastCompletedAt = Date()
                mutable.lastError = summary.errorMessage
                mutable.lastStatus = summary.status
                if summary.errorMessage != nil {
                    mutable.recordFailure()
                } else {
                    mutable.recordSuccess()
                }
            }
            return mutable
        }

        let runRecord = MaterialRunRecord(
            startedAt: startedAt,
            endedAt: Date(),
            articleCount: deduplicatedArticles.count,
            candidateCount: candidates.count,
            errorMessages: sourceErrors + cleanedCandidates.compactMap { candidate in
                candidate.failureReasons.isEmpty ? nil : "\(candidate.sourceArticle.title)：\(candidate.failureReasons.joined(separator: "；"))"
            },
            sourceSummaries: updatedSummaries
        )

        return MaterialsPipelineOutcome(
            candidates: candidates,
            runRecord: runRecord,
            updatedSourceConfigs: updatedConfigs
        )
    }

    func rebuildCandidate(
        from article: SourceArticle,
        settings: TrainingSettings,
        existingID: String,
        recentMaterialHints: [String],
        onProgress: (@Sendable (MaterialsPipelineProgress) -> Void)? = nil
    ) async -> MaterialCandidate {
        let candidate = await buildCandidate(from: article, settings: settings, recentMaterialHints: recentMaterialHints, onProgress: onProgress)
        var rebuilt = candidate
        rebuilt.id = existingID
        rebuilt.updatedAt = Date()
        return rebuilt
    }

    actor ProgressTracker {
        var completed: Int = 0
        func increment() -> Int {
            completed += 1
            return completed
        }
    }

    private func buildCandidates(
        from articles: [SourceArticle],
        settings: TrainingSettings,
        recentMaterialHints: [String],
        onProgress: (@Sendable (MaterialsPipelineProgress) -> Void)?
    ) async -> [MaterialCandidate] {
        let total = articles.count
        let tracker = ProgressTracker()

        return await withTaskGroup(of: MaterialCandidate.self) { group in
            for article in articles {
                group.addTask {
                    let candidate = await self.buildCandidate(from: article, settings: settings, recentMaterialHints: recentMaterialHints) { progress in
                        onProgress?(MaterialsPipelineProgress(
                            phase: "AI 并发处理中 (\(total) 篇)",
                            fractionCompleted: progress.fractionCompleted, // child phase
                            logMessage: progress.logMessage
                        ))
                    }
                    let current = await tracker.increment()
                    onProgress?(MaterialsPipelineProgress(
                        phase: "AI 并发处理中 (\(total) 篇)",
                        fractionCompleted: 0.5 + 0.5 * (Double(current) / Double(total)),
                        logMessage: "✅ 完成《\(article.title)》的清洗 (\(current)/\(total))"
                    ))
                    return candidate
                }
            }
            
            var candidates: [MaterialCandidate] = []
            for await candidate in group {
                candidates.append(candidate)
            }
            return candidates
        }
    }

    private func buildCandidate(
        from article: SourceArticle,
        settings: TrainingSettings,
        recentMaterialHints: [String],
        onProgress: (@Sendable (MaterialsPipelineProgress) -> Void)? = nil
    ) async -> MaterialCandidate {
        let client = AIClient(
            baseURL: settings.aiBaseURL,
            apiKey: settings.aiAPIKey,
            model: settings.aiModel
        )
        let report: (String) -> Void = { msg in
            onProgress?(MaterialsPipelineProgress(phase: "", fractionCompleted: 0, logMessage: msg))
        }
        var debugLogs = [
            "开始处理来源：\(article.sourceKind.title)",
            "原始标题：\(article.title)",
            "模型：\(settings.aiModel)"
        ]
        debugLogs.forEach(report)

        report("正在请求清洗正文细节...")
        do {
            let condensedResult = try await client.requestJSON(
                system: "你只输出严格 JSON，不要解释。",
                user: Self.condensePrompt(article: article, recentMaterialHints: recentMaterialHints),
                responseType: CondensedPassageDraft.self,
                stage: "正文清洗",
                toolSchemaJSON: Self.condensePassageSchema
            )
            let condensed = condensedResult.value
            condensedResult.logs.forEach(report)
            debugLogs.append(contentsOf: condensedResult.logs)
            
            if condensed.isDuplicate == true {
                let msg = "🚫 智能排重：与近期材料过于相似，自主熔断抛弃《\(condensed.title)》"
                report(msg)
                debugLogs.append(msg)
                
                return MaterialCandidate(
                    sourceArticle: article,
                    generatedPassage: nil,
                    localizedTitle: nil,
                    generatedSummary: "预审被判定为重复知识，已被跳过。",
                    score: 0,
                    ruleScore: 0,
                    aiScore: 0,
                    suggestedDifficulty: 1,
                    status: .pending,
                    failureReasons: ["AI自动查重：被大模型判定为与近期素材高度雷同的新闻/文章。"],
                    debugLogs: debugLogs,
                    cleaningModel: settings.aiModel
                )
            }
            
            let m1 = "中文正文清洗完成：\(condensed.title)"
            report(m1)
            debugLogs.append(m1)

            report("尝试解析逻辑链、主旨与回忆结构...")
            let generatedResult = try await client.requestJSON(
                system: "你只输出严格 JSON，不要解释。",
                user: Self.generatePassagePrompt(article: article, condensed: condensed, recentMaterialHints: recentMaterialHints),
                responseType: GeneratedPassagePayload.self,
                stage: "结构化生成",
                toolSchemaJSON: Self.generatePassageSchema
            )
            let generated = generatedResult.value
            generatedResult.logs.forEach(report)
            debugLogs.append(contentsOf: generatedResult.logs)
            let m2 = "结构化生成完成：主旨选项 \(generated.mainIdeaOptions.count) 项，证据 \(generated.evidenceItems.count) 条"
            report(m2)
            debugLogs.append(m2)

            let passage = ReadingPassage(
                id: StableMaterialID.make(prefix: article.sourceKind.rawValue, seed: article.url),
                title: generated.title.isEmpty ? condensed.title : generated.title,
                domainTag: condensed.domainTag,
                difficulty: generated.difficulty,
                structureType: condensed.structureType,
                body: condensed.body,
                mainIdeaOptions: generated.mainIdeaOptions,
                mainIdeaAnswerIndex: generated.mainIdeaAnswerIndex,
                mainIdeaRubric: generated.mainIdeaRubric,
                claimAnchors: generated.claimAnchors,
                evidenceItems: generated.evidenceItems,
                recallPrompts: generated.recallPrompts,
                recallKeywords: generated.recallKeywords
            )
            let ruleScore = MaterialCandidateScorer.ruleScore(for: passage)
            let issues = passage.validationIssues
            let aiScore = generated.aiSelfScore
            let score = (0.4 * aiScore + 0.6 * ruleScore).rounded()

            // Overlap check: verify AI output is grounded in source
            var allRiskNotes = generated.riskNotes
            let overlapRate = ContentOverlapChecker.overlapRate(
                source: article.aiInputText,
                generated: condensed.body
            )
            debugLogs.append("原文重叠率：\(Int(overlapRate * 100))%")
            if overlapRate < 0.25 {
                allRiskNotes.append("⚠️ 生成正文与原文关键词重叠率仅 \(Int(overlapRate * 100))%，可能偏离原文。")
            }

            debugLogs.append("中文标题：\(condensed.title)")
            debugLogs.append("结构：\(condensed.structureType.label) · 难度 \(passage.difficulty)")
            debugLogs.append("AI 评分：\(Int(aiScore))")
            debugLogs.append("AI 评分理由：\(generated.scoreReason)")
            debugLogs.append("规则校验分：\(Int(ruleScore))")
            debugLogs.append("综合分：\(Int(score))（0.4×AI + 0.6×规则）")
            if !issues.isEmpty {
                debugLogs.append("结构校验：\(issues.joined(separator: "；"))")
            }
            return MaterialCandidate(
                sourceArticle: article,
                generatedPassage: passage,
                localizedTitle: passage.title,
                generatedSummary: condensed.body,
                score: score,
                ruleScore: ruleScore,
                aiScore: aiScore,
                suggestedDifficulty: passage.difficulty,
                status: .pending,
                failureReasons: issues + allRiskNotes,
                debugLogs: debugLogs,
                cleaningModel: settings.aiModel
            )
        } catch {
            debugLogs.append(contentsOf: error.materialsDebugLogs)
            return MaterialCandidate(
                sourceArticle: article,
                generatedPassage: nil,
                localizedTitle: nil,
                generatedSummary: "原文预览（未完成中文清洗）：\(article.excerpt)",
                score: 0,
                ruleScore: 0,
                aiScore: 0,
                suggestedDifficulty: 1,
                status: .pending,
                failureReasons: failureReasons(from: error),
                debugLogs: debugLogs,
                cleaningModel: settings.aiModel
            )
        }
    }

    private func deduplicateArticles(_ articles: [SourceArticle]) -> [SourceArticle] {
        var urlSeen: Set<String> = []
        var titleSeen: Set<String> = []
        var fingerprintSeen: Set<String> = []
        var kept: [SourceArticle] = []

        for article in articles.sorted(by: { articleSortOrder(lhs: $0, rhs: $1) }) {
            let normalizedURL = article.url.normalizedMaterialURL
            let normalizedTitle = article.title.normalizedMaterialToken
            let fingerprint = article.aiInputText.materialFingerprint
            if !normalizedURL.isEmpty, !urlSeen.insert(normalizedURL).inserted {
                continue
            }
            if !normalizedTitle.isEmpty, !titleSeen.insert(normalizedTitle).inserted {
                continue
            }
            if !fingerprint.isEmpty, !fingerprintSeen.insert(fingerprint).inserted {
                continue
            }
            if kept.contains(where: { existing in
                existing.title.normalizedMaterialToken == normalizedTitle
                    || existing.aiInputText.materialFingerprint == fingerprint
            }) {
                continue
            }
            kept.append(article)
        }
        return kept
    }

    private func articleSortOrder(lhs: SourceArticle, rhs: SourceArticle) -> Bool {
        switch (lhs.sourceKind.cadence, rhs.sourceKind.cadence) {
        case (.timely, .evergreen), (.timely, .protectedAttempt), (.evergreen, .protectedAttempt):
            return true
        case (.protectedAttempt, .timely), (.protectedAttempt, .evergreen), (.evergreen, .timely):
            return false
        default:
            switch (lhs.publishedAt, rhs.publishedAt) {
            case let (left?, right?):
                return left > right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return lhs.fetchedAt > rhs.fetchedAt
            }
        }
    }
}

private extension Error {
    var materialsDebugLogs: [String] {
        if let pipelineError = self as? MaterialsPipelineError {
            return pipelineError.debugLogs
        }
        return [localizedDescription]
    }
}

private func failureReasons(from error: Error) -> [String] {
    var reasons = [error.localizedDescription]
    if let firstDebugLog = error.materialsDebugLogs.first, firstDebugLog != error.localizedDescription {
        reasons.append(firstDebugLog)
    }
    var seen: Set<String> = []
    return reasons.filter { seen.insert($0).inserted }
}

private enum MaterialCandidateScorer {
    static func ruleScore(for passage: ReadingPassage) -> Double {
        var score = 0.0
        score += passage.mainIdeaOptions.count == 4 ? 18 : 0
        score += passage.mainIdeaOptions.indices.contains(passage.mainIdeaAnswerIndex) ? 12 : 0
        score += passage.claimAnchors.count >= 2 ? 15 : 8
        score += passage.evidenceItems.count >= 4 ? 15 : 8
        score += passage.recallPrompts.count >= 5 ? 15 : 8
        score += passage.recallKeywords.count >= 5 ? 10 : 5
        score += (700...2_200).contains(passage.body.count) ? 10 : 4
        score += passage.validationIssues.isEmpty ? 5 : 0
        return min(score, 100)
    }
}

private struct MaterialSourceCrawler {
    let sourceKind: ConcreteSourceKind
    let session: URLSession

    func fetchArticles(limit: Int) async throws -> SourceFetchOutcome {
        switch sourceKind {
        case .ourWorldInData:
            return try await fetchFeedBackedArticles(from: sourceKind.seedURL, limit: limit)
        case .nasa:
            return try await fetchFeedBackedArticles(from: sourceKind.seedURL, limit: limit)
        case .openStax:
            return try await fetchOpenStaxArticles(limit: limit)
        case .cdc:
            return try await fetchListBackedArticles(limit: limit)
        default:
            return try await fetchListBackedArticles(limit: limit)
        }
    }

    private func fetchFeedBackedArticles(from url: URL, limit: Int) async throws -> SourceFetchOutcome {
        let xml = try await loadText(from: url)
        let feedEntries = try SyndicationFeedParser.parse(xml: xml)
            .sorted { lhs, rhs in
                switch (lhs.publishedAt, rhs.publishedAt) {
                case let (left?, right?):
                    left > right
                case (_?, nil):
                    true
                default:
                    false
                }
            }

        var articles: [SourceArticle] = []
        var rejectedBodyCount = 0
        for entry in feedEntries.prefix(limit) {
            guard let link = URL(string: entry.link), link.pathExtension.lowercased() != "pdf" else { continue }
            let articleHTML = (try? await loadText(from: link)) ?? ""
            let extraction = HTMLContentExtractor.articleBodyResult(from: articleHTML, fallback: entry.summary)
            let sourceText = extraction.body
            let excerpt = HTMLContentExtractor.previewText(from: sourceText)
            guard sourceText.count >= 180 else {
                rejectedBodyCount += 1
                continue
            }
            articles.append(
                SourceArticle(
                    sourceKind: sourceKind,
                    title: entry.title,
                    url: entry.link,
                    summary: entry.summary,
                    excerpt: excerpt,
                    sourceText: sourceText,
                    publishedAt: entry.publishedAt,
                    author: entry.author,
                    domainTag: sourceKind.sourceDomainLabel
                )
            )
        }
        guard !articles.isEmpty else {
            throw SourceFetchError.emptyContent(message: "\(sourceKind.title) 未抓到可用文章。Feed 条目 \(feedEntries.count) 条，正文不合格 \(rejectedBodyCount) 条。")
        }
        return SourceFetchOutcome(
            articles: articles,
            status: .healthy,
            detailMessage: "Feed 条目 \(feedEntries.count) 条，成功正文 \(articles.count) 篇，正文不合格 \(rejectedBodyCount) 条。"
        )
    }

    private func fetchListBackedArticles(limit: Int) async throws -> SourceFetchOutcome {
        let html = try await loadText(from: sourceKind.seedURL)
        let links = HTMLContentExtractor.extractCandidateLinks(
            from: html,
            baseURL: sourceKind.seedURL,
            kind: sourceKind,
            limit: max(limit * 8, 16)
        )
        let discoveredCount = links.count
        if links.isEmpty {
            throw SourceFetchError.parseFailure(
                message: "\(sourceKind.title) 列表页可访问，但当前抓取规则没有命中文章链接。"
            )
        }
        var articles: [SourceArticle] = []
        var inspectedCount = 0
        var rejectedBodyCount = 0
        for linkString in links {
            if articles.count >= limit { break }
            guard let url = URL(string: linkString) else { continue }
            inspectedCount += 1
            let articleHTML: String
            do {
                articleHTML = try await loadText(from: url)
            } catch {
                continue
            }
            let title = HTMLContentExtractor.bestTitle(from: articleHTML) ?? url.lastPathComponent
            let extraction = HTMLContentExtractor.articleBodyResult(from: articleHTML, fallback: "")
            let sourceText = extraction.body
            let excerpt = HTMLContentExtractor.previewText(from: sourceText)
            guard sourceText.count >= 180 else {
                rejectedBodyCount += 1
                continue
            }
            articles.append(
                SourceArticle(
                    sourceKind: sourceKind,
                    title: title,
                    url: linkString,
                    summary: HTMLContentExtractor.metaDescription(from: articleHTML) ?? sourceKind.subtitle,
                    excerpt: excerpt,
                    sourceText: sourceText,
                    publishedAt: HTMLContentExtractor.publishedAt(from: articleHTML, url: url),
                    domainTag: sourceKind.sourceDomainLabel
                )
            )
        }

        if articles.isEmpty {
            throw SourceFetchError.emptyContent(
                message: "\(sourceKind.title) 未抓到可用正文。发现候选 \(discoveredCount) 个，实际打开 \(inspectedCount) 个，正文不合格 \(rejectedBodyCount) 个。"
            )
        }
        return SourceFetchOutcome(
            articles: articles,
            status: .healthy,
            detailMessage: "发现候选 \(discoveredCount) 个，实际打开 \(inspectedCount) 个，成功正文 \(articles.count) 篇，正文不合格 \(rejectedBodyCount) 个。"
        )
    }

    private func fetchOpenStaxArticles(limit: Int) async throws -> SourceFetchOutcome {
        let data = try await loadData(from: URL(string: "https://openstax.org/apps/cms/api/books/?format=json")!)
        let decoded = try JSONDecoder().decode(OpenStaxBooksIndex.self, from: data)
        let books = decoded.books.filter { $0.bookState == "live" }
        var articles: [SourceArticle] = []
        var inspectedCount = 0
        var rejectedBodyCount = 0

        for book in books {
            if articles.count >= limit { break }
            guard let link = book.preferredLink else { continue }
            inspectedCount += 1
            let html: String
            do {
                html = try await loadText(from: link)
            } catch {
                continue
            }
            let extraction = HTMLContentExtractor.articleBodyResult(from: html, fallback: book.title)
            let sourceText = extraction.body
            guard sourceText.count >= 180 else {
                rejectedBodyCount += 1
                continue
            }
            let subjects = book.subjects.joined(separator: " · ")
            articles.append(
                SourceArticle(
                    sourceKind: sourceKind,
                    title: book.title,
                    url: link.absoluteString,
                    summary: subjects.isEmpty ? sourceKind.subtitle : subjects,
                    excerpt: HTMLContentExtractor.previewText(from: sourceText),
                    sourceText: sourceText,
                    publishedAt: nil,
                    domainTag: sourceKind.sourceDomainLabel
                )
            )
        }

        if articles.isEmpty {
            throw SourceFetchError.emptyContent(
                message: "\(sourceKind.title) 书目接口可用，但未抓到可用正文。书目 \(books.count) 本，实际打开 \(inspectedCount) 本，正文不合格 \(rejectedBodyCount) 本。"
            )
        }

        return SourceFetchOutcome(
            articles: articles,
            status: .healthy,
            detailMessage: "书目 \(books.count) 本，实际打开 \(inspectedCount) 本，成功正文 \(articles.count) 篇，正文不合格 \(rejectedBodyCount) 本。"
        )
    }

    private func loadData(from url: URL) async throws -> Data {
        var lastError: Error?
        for attempt in 1...2 {
            do {
                let request = buildRequest(for: url)
                let (data, response) = try await session.data(for: request)
                try HTTPResponseValidator.validate(response: response, data: data, url: url)
                return data
            } catch {
                lastError = classifyTransportError(error, url: url)
                if attempt == 1, shouldRetry(error: lastError) {
                    try? await Task.sleep(for: .milliseconds(400 * attempt))
                    continue
                }
                throw lastError ?? error
            }
        }
        throw lastError ?? SourceFetchError.network(message: "\(sourceKind.title) 抓取失败。")
    }

    private func loadText(from url: URL) async throws -> String {
        let data = try await loadData(from: url)
        return String(decoding: data, as: UTF8.self)
    }

    private func buildRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        return request
    }

    private func classifyTransportError(_ error: Error, url: URL) -> Error {
        if let fetchError = error as? SourceFetchError {
            return fetchError
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return SourceFetchError.timeout(message: "\(sourceKind.title) 请求超时。")
            default:
                return SourceFetchError.network(message: "\(sourceKind.title) 网络失败：\(urlError.localizedDescription)")
            }
        }
        return SourceFetchError.network(message: "\(sourceKind.title) 网络失败：\(error.localizedDescription)")
    }

    private func shouldRetry(error: Error?) -> Bool {
        guard let fetchError = error as? SourceFetchError else { return false }
        return switch fetchError {
        case .timeout, .network:
            true
        case .protectedSource, .parseFailure, .emptyContent, .http:
            false
        }
    }
}

private extension MaterialsPipeline {
    static func condensePrompt(article: SourceArticle, recentMaterialHints: [String]) -> String {
        let duplicateHints = recentMaterialHints.isEmpty
            ? "暂无近期素材。"
            : recentMaterialHints.prefix(12).joined(separator: "\n")
        return """
        你是阅读训练题库编辑。请把原始材料清洗成一篇完整的中文阅读训练文章。

        约束：
        1. 仅输出 JSON。
        2. 不要输出 Markdown，不要输出 ```json 代码块，不要输出解释文字。
        3. 输出必须是单个 JSON 对象，首字符是 {，末字符是 }。
        4. 所有 JSON 字符串都必须合法转义；如果正文里出现双引号，必须写成 \\"。
        5. 内容必须忠于来源，不得虚构新事实。
        6. 这是"训练正文清洗"，不是摘要。不要只摘其中一段，要覆盖来源中的主要背景、关键机制或证据、主要结论、必要限制。
        7. 如果原文很长，可以压缩表达，但不能遗漏核心信息；要把信息组织成适合阅读训练的完整文章。
        8. 正文优先保证完整，长度控制在 800 到 1,800 个中文字符。
        9. structureType 只能是 causeEffect / compareContrast / problemSolution / mechanism。
        10. difficulty 只能是数字 1 / 2 / 3，不能输出字符串。
        11. 如果这篇文章的内容与“近期已有材料”高度重合且无任何独特新信息（完全在重复之前的话题或结论），务必将 `isDuplicate` 置为 true。反之为 false。不要强行输出 true 除非确实雷同。

        合法示例：
        {
          "title": "海洋牧场为何需要长期生态修复",
          "domainTag": "海洋科学",
          "difficulty": 2,
          "structureType": "problemSolution",
          "body": "沿海地区曾长期把海洋当作高强度开发空间，导致部分海域生态退化、渔业资源下降。近年一些地区开始建设海洋牧场，但实践表明，单纯投放设施并不能自动恢复生态系统。研究者指出，海洋牧场要真正发挥作用，必须把栖息地修复、水质治理和渔业管理结合起来。首先，受损海底环境如果没有恢复，人工设施就难以形成稳定的生物栖息空间。其次，陆源污染持续进入海域，会削弱海洋生物的繁殖与生长条件。再次，若捕捞压力过大，即使局部海域短期出现资源回升，也难以形成长期稳定的生态收益。因此，海洋牧场建设的关键不是单一工程投入，而是把生态修复、污染控制和资源管理纳入同一治理框架。只有这样，海洋牧场才可能同时承担生态保护和渔业增效的双重任务。",
          "isDuplicate": false
        }

        输出 JSON 结构：
        {
          "title": "中文标题",
          "domainTag": "领域标签",
          "difficulty": 2,
          "structureType": "compareContrast",
          "body": "完整中文训练正文",
          "isDuplicate": false
        }

        来源标题：\(article.title)
        来源时间：\(article.publishedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "未知")
        来源摘要：\(article.summary)
        近期已有材料（避免重复）：
        \(duplicateHints)
        来源正文全文：
        \(article.aiInputText)
        """
    }

    static func generatePassagePrompt(article: SourceArticle, condensed: CondensedPassageDraft, recentMaterialHints: [String]) -> String {
        let duplicateHints = recentMaterialHints.isEmpty
            ? "暂无近期素材。"
            : recentMaterialHints.prefix(12).joined(separator: "\n")
        return """
        你是阅读训练题库编辑。请基于给定短文输出完整训练结构，只能输出 JSON。

        要求：
        1. 只输出单个 JSON 对象，不要输出 Markdown，不要输出 ```json 代码块，不要输出解释文字。
        2. 所有 JSON 字符串都必须合法转义；如果字符串中出现双引号，必须写成 \\"。
        3. 所有字段都必须与正文一致。
        4. `mainIdeaOptions` 必须恰好 4 项，只有 1 个正确答案。
        5. `claimAnchors` 至少 2 项，其中至少 1 个 `scope=global`。
        6. `evidenceItems` 至少 4 项。
        7. `evidenceItems.role` 只能是 claim / evidence / background / limitation。严禁输出 concession / support / context / conclusion 等其他值。
        8. `claimAnchors.scope` 只能是 global 或 local。
        9. `recallPrompts` 至少 5 项，真假混合。
        10. `recallKeywords` 至少 5 项。
        11. `difficulty` 由你根据正文真实难度判断，必须是数字 1 / 2 / 3，不能输出字符串。
        12. `mainIdeaAnswerIndex` 必须是数字 0 到 3。
        13. `aiSelfScore` 取 0 到 100 的整数。
        14. `scoreReason` 用中文一句话解释评分依据，重点看完整度、清晰度、训练价值。
        15. `riskNotes` 写潜在风险；如果没有，返回空数组。
        16. 避免和近期材料重复题干、重复干扰项、重复证据映射角度；如果高度相似，必须在 `riskNotes` 标出。

        合法示例：
        {
          "title": "气候变化对珊瑚礁生态系统的影响",
          "difficulty": 2,
          "mainIdeaOptions": [
            "短期热浪是珊瑚礁退化的唯一原因",
            "气候变化从多个途径削弱珊瑚礁稳定性，局部保护措施只能部分缓冲风险",
            "只要减少过度捕捞，就能彻底阻止珊瑚白化",
            "海水酸化对珊瑚的影响已经被证明可以忽略"
          ],
          "mainIdeaAnswerIndex": 1,
          "mainIdeaRubric": {
            "idealSummary": "气候变化通过升温、酸化和极端天气破坏珊瑚礁生态系统，局部保护措施虽有帮助，但不足以抵消全球变暖风险。",
            "keywords": ["气候变化", "珊瑚礁", "白化", "酸化", "恢复力"],
            "trapNote": "错误选项分别夸大单一原因、夸大局部措施效果或否认已知风险。"
          },
          "claimAnchors": [
            { "id": "claim-1", "text": "气候变化从多个途径破坏珊瑚礁稳定性", "scope": "global" },
            { "id": "claim-2", "text": "局部保护措施只能部分缓冲风险", "scope": "local" }
          ],
          "evidenceItems": [
            { "id": "e1", "text": "短期热浪会导致珊瑚白化", "role": "evidence", "supportsClaimID": "claim-1" },
            { "id": "e2", "text": "长期酸化削弱珊瑚骨骼形成能力", "role": "evidence", "supportsClaimID": "claim-1" },
            { "id": "e3", "text": "减少局部污染和限制过度捕捞能提高恢复力", "role": "background", "supportsClaimID": null },
            { "id": "e4", "text": "局部措施不能完全抵消全球变暖风险", "role": "limitation", "supportsClaimID": "claim-2" }
          ],
          "recallPrompts": [
            { "id": "r1", "text": "气候变化会通过多种机制影响珊瑚礁。", "isTarget": true },
            { "id": "r2", "text": "原文认为局部保护措施足以消除全球变暖风险。", "isTarget": false },
            { "id": "r3", "text": "热浪和酸化分别对应不同类型的生态伤害。", "isTarget": true },
            { "id": "r4", "text": "文中提到减少污染和限制过度捕捞。", "isTarget": true },
            { "id": "r5", "text": "原文否认海水升温与珊瑚白化有关。", "isTarget": false }
          ],
          "recallKeywords": ["白化", "酸化", "热浪", "恢复力", "全球变暖"],
          "aiSelfScore": 86,
          "scoreReason": "文章论点集中，证据关系清楚，适合做主旨与证据训练。",
          "riskNotes": []
        }

        输出 JSON 结构：
        {
          "title": "中文标题",
          "difficulty": 2,
          "mainIdeaOptions": ["", "", "", ""],
          "mainIdeaAnswerIndex": 1,
          "mainIdeaRubric": {
            "idealSummary": "",
            "keywords": ["", ""],
            "trapNote": ""
          },
          "claimAnchors": [
            { "id": "claim-1", "text": "", "scope": "global" }
          ],
          "evidenceItems": [
            { "id": "e1", "text": "", "role": "evidence", "supportsClaimID": "claim-1" }
          ],
          "recallPrompts": [
            { "id": "r1", "text": "", "isTarget": true }
          ],
          "recallKeywords": ["", ""],
          "aiSelfScore": 84,
          "scoreReason": "这篇文章信息完整、结构清楚，适合阅读训练。",
          "riskNotes": []
        }

        来源标题：\(article.title)
        训练标题：\(condensed.title)
        领域：\(condensed.domainTag)
        难度：\(condensed.difficulty)
        结构：\(condensed.structureType.rawValue)
        近期已有材料（避免重复）：
        \(duplicateHints)
        正文：\(condensed.body)
        """
    }

    static var condensePassageSchema: String {
        return """
        {
          "type": "object",
          "properties": {
            "title": { "type": "string" },
            "domainTag": { "type": "string" },
            "difficulty": { "type": "integer" },
            "structureType": { "type": "string", "enum": ["causeEffect", "compareContrast", "problemSolution", "mechanism"] },
            "body": { "type": "string" },
            "isDuplicate": { "type": "boolean" }
          },
          "required": ["title", "domainTag", "difficulty", "structureType", "body"]
        }
        """
    }

    static var generatePassageSchema: String {
        return """
        {
          "type": "object",
          "properties": {
            "title": { "type": "string" },
            "difficulty": { "type": "integer" },
            "mainIdeaOptions": { "type": "array", "items": { "type": "string" } },
            "mainIdeaAnswerIndex": { "type": "integer" },
            "mainIdeaRubric": {
              "type": "object",
              "properties": {
                "idealSummary": { "type": "string" },
                "keywords": { "type": "array", "items": { "type": "string" } },
                "trapNote": { "type": "string" }
              },
              "required": ["idealSummary", "keywords", "trapNote"]
            },
            "claimAnchors": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "id": { "type": "string" },
                  "text": { "type": "string" },
                  "scope": { "type": "string", "enum": ["global", "local"] }
                },
                "required": ["id", "text", "scope"]
              }
            },
            "evidenceItems": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "id": { "type": "string" },
                  "text": { "type": "string" },
                  "role": { "type": "string", "enum": ["claim", "evidence", "background", "limitation"] },
                  "supportsClaimID": { "type": ["string", "null"] }
                },
                "required": ["id", "text", "role"]
              }
            },
            "recallPrompts": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "id": { "type": "string" },
                  "text": { "type": "string" },
                  "isTarget": { "type": "boolean" }
                },
                "required": ["id", "text", "isTarget"]
              }
            },
            "recallKeywords": { "type": "array", "items": { "type": "string" } },
            "aiSelfScore": { "type": "number" },
            "scoreReason": { "type": "string" },
            "riskNotes": { "type": "array", "items": { "type": "string" } }
          },
          "required": [
            "title", "difficulty", "mainIdeaOptions", "mainIdeaAnswerIndex",
            "mainIdeaRubric", "claimAnchors", "evidenceItems", "recallPrompts",
            "recallKeywords", "aiSelfScore", "scoreReason", "riskNotes"
          ]
        }
        """
    }
}

enum ContentOverlapChecker {
    static func overlapRate(source: String, generated: String) -> Double {
        let sourceTokens = extractTokens(from: source)
        let generatedTokens = extractTokens(from: generated)
        guard !generatedTokens.isEmpty else { return 0 }
        let intersection = generatedTokens.intersection(sourceTokens)
        return Double(intersection.count) / Double(generatedTokens.count)
    }

    private static func extractTokens(from text: String) -> Set<String> {
        let cleaned = text
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
            .lowercased()
        // For Chinese, use 2-gram sliding window; for Latin, use whitespace split
        var tokens: Set<String> = []
        let words = cleaned.split(separator: " ").map(String.init)
        for word in words {
            if word.count >= 2 {
                tokens.insert(word)
            }
            // Chinese 2-gram
            let chars = Array(word)
            if chars.count >= 2 {
                for i in 0..<(chars.count - 1) {
                    tokens.insert(String(chars[i...i+1]))
                }
            }
        }
        return tokens
    }
}

struct CondensedPassageDraft: Codable {
    var title: String
    var domainTag: String
    var difficulty: Int
    var structureType: ReadingStructureType
    var body: String
    var isDuplicate: Bool?

    init(title: String, domainTag: String, difficulty: Int, structureType: ReadingStructureType, body: String, isDuplicate: Bool? = nil) {
        self.title = title
        self.domainTag = domainTag
        self.difficulty = difficulty
        self.structureType = structureType
        self.body = body
        self.isDuplicate = isDuplicate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        domainTag = try container.decode(String.self, forKey: .domainTag)
        difficulty = try container.decodeFlexibleInt(forKey: .difficulty)
        structureType = try ReadingStructureType(normalizing: container.decodeFlexibleString(forKey: .structureType))
        body = try container.decode(String.self, forKey: .body)
        isDuplicate = try? container.decodeIfPresent(Bool.self, forKey: .isDuplicate)
    }
}

struct GeneratedPassagePayload: Codable {
    var title: String
    var difficulty: Int
    var mainIdeaOptions: [String]
    var mainIdeaAnswerIndex: Int
    var mainIdeaRubric: MainIdeaRubric
    var claimAnchors: [ReadingClaimAnchor]
    var evidenceItems: [EvidenceClassificationItem]
    var recallPrompts: [DelayedRecallPrompt]
    var recallKeywords: [String]
    var aiSelfScore: Double
    var scoreReason: String
    var riskNotes: [String]

    init(
        title: String,
        difficulty: Int,
        mainIdeaOptions: [String],
        mainIdeaAnswerIndex: Int,
        mainIdeaRubric: MainIdeaRubric,
        claimAnchors: [ReadingClaimAnchor],
        evidenceItems: [EvidenceClassificationItem],
        recallPrompts: [DelayedRecallPrompt],
        recallKeywords: [String],
        aiSelfScore: Double,
        scoreReason: String,
        riskNotes: [String]
    ) {
        self.title = title
        self.difficulty = difficulty
        self.mainIdeaOptions = mainIdeaOptions
        self.mainIdeaAnswerIndex = mainIdeaAnswerIndex
        self.mainIdeaRubric = mainIdeaRubric
        self.claimAnchors = claimAnchors
        self.evidenceItems = evidenceItems
        self.recallPrompts = recallPrompts
        self.recallKeywords = recallKeywords
        self.aiSelfScore = aiSelfScore
        self.scoreReason = scoreReason
        self.riskNotes = riskNotes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        difficulty = try container.decodeFlexibleInt(forKey: .difficulty)
        mainIdeaOptions = try container.decode([String].self, forKey: .mainIdeaOptions)
        mainIdeaAnswerIndex = try container.decodeFlexibleInt(forKey: .mainIdeaAnswerIndex)
        mainIdeaRubric = try container.decode(MainIdeaRubric.self, forKey: .mainIdeaRubric)

        let rawClaims = try container.decode([LooseClaimAnchor].self, forKey: .claimAnchors)
        claimAnchors = try rawClaims.map {
            ReadingClaimAnchor(
                id: $0.id,
                text: $0.text,
                scope: try ReadingClaimAnchor.Scope(normalizing: $0.scope)
            )
        }

        let rawEvidence = try container.decode([LooseEvidenceItem].self, forKey: .evidenceItems)
        evidenceItems = try rawEvidence.map {
            EvidenceClassificationItem(
                id: $0.id,
                text: $0.text,
                role: try EvidenceClassificationItem.Role(normalizing: $0.role),
                supportsClaimID: $0.supportsClaimID
            )
        }

        let rawPrompts = try container.decode([LooseRecallPrompt].self, forKey: .recallPrompts)
        recallPrompts = rawPrompts.map {
            DelayedRecallPrompt(id: $0.id, text: $0.text, isTarget: $0.isTarget)
        }
        recallKeywords = try container.decode([String].self, forKey: .recallKeywords)
        aiSelfScore = try container.decodeFlexibleDouble(forKey: .aiSelfScore)
        scoreReason = try container.decode(String.self, forKey: .scoreReason)
        riskNotes = (try? container.decode([String].self, forKey: .riskNotes)) ?? []
    }
}

private struct LooseClaimAnchor: Codable {
    var id: String
    var text: String
    var scope: String
}

private struct LooseEvidenceItem: Codable {
    var id: String
    var text: String
    var role: String
    var supportsClaimID: String?
}

private struct LooseRecallPrompt: Codable {
    var id: String
    var text: String
    var isTarget: Bool
}

private struct HTTPResponseValidator {
    static func validate(response: URLResponse, data: Data, url: URL? = nil) throws {
        guard let response = response as? HTTPURLResponse else { return }
        let bodyPreview = String(decoding: data.prefix(320), as: UTF8.self)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if looksLikeProtectedChallenge(bodyPreview) {
            throw SourceFetchError.protectedSource(message: "\(url?.host ?? "该来源") 返回了反爬挑战页，已跳过。")
        }
        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 403 || looksLikeProtectedChallenge(bodyPreview) {
                throw SourceFetchError.protectedSource(message: "\(url?.host ?? "该来源") 受反爬或访问保护，已跳过。")
            }
            throw SourceFetchError.http(
                statusCode: response.statusCode,
                message: "HTTP \(response.statusCode)：\(bodyPreview.prefix(120))"
            )
        }
    }

    private static func looksLikeProtectedChallenge(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered.contains("just a moment")
            || lowered.contains("cf-browser-verification")
            || lowered.contains("attention required")
            || lowered.contains("/tspd/")
            || lowered.contains("window[\"bobcmn\"]")
            || lowered.contains("challenge-platform")
            || lowered.contains("captcha")
    }
}

private struct SyndicationFeedEntry {
    var title: String
    var link: String
    var summary: String
    var publishedAt: Date?
    var author: String?
}

private final class SyndicationFeedParser: NSObject, XMLParserDelegate {
    private var entries: [SyndicationFeedEntry] = []
    private var currentTitle = ""
    private var currentLink = ""
    private var currentSummary = ""
    private var currentAuthor = ""
    private var currentPublished = ""
    private var currentElement = ""
    private var insideEntry = false
    private var buffer = ""

    static func parse(xml: String) throws -> [SyndicationFeedEntry] {
        let parser = XMLParser(data: Data(xml.utf8))
        let delegate = SyndicationFeedParser()
        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError ?? URLError(.cannotParseResponse)
        }
        return delegate.entries
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let normalized = qName ?? elementName
        currentElement = normalized.lowercased()
        if currentElement == "item" || currentElement == "entry" {
            insideEntry = true
            currentTitle = ""
            currentLink = ""
            currentSummary = ""
            currentAuthor = ""
            currentPublished = ""
        }
        if insideEntry, currentElement == "link", let href = attributeDict["href"], !href.isEmpty {
            currentLink = href
        }
        buffer = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer.append(string)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let normalized = (qName ?? elementName).lowercased()
        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)

        guard insideEntry else {
            buffer = ""
            return
        }

        switch normalized {
        case "title":
            currentTitle = text
        case "link":
            if currentLink.isEmpty {
                currentLink = text
            }
        case "description", "summary", "content:encoded":
            if currentSummary.count < text.count {
                currentSummary = text
            }
        case "published", "pubdate", "updated":
            if currentPublished.isEmpty {
                currentPublished = text
            }
        case "name", "dc:creator", "author":
            if currentAuthor.isEmpty {
                currentAuthor = text
            }
        case "item", "entry":
            insideEntry = false
            if !currentTitle.isEmpty, !currentLink.isEmpty {
                entries.append(
                    SyndicationFeedEntry(
                        title: currentTitle.plainHTMLText,
                        link: currentLink.plainHTMLText,
                        summary: currentSummary.plainHTMLText,
                        publishedAt: FeedDateParser.parse(currentPublished),
                        author: currentAuthor.isEmpty ? nil : currentAuthor.plainHTMLText
                    )
                )
            }
        default:
            break
        }

        buffer = ""
    }
}

private enum FeedDateParser {
    static func parse(_ raw: String) -> Date? {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let iso = ISO8601DateFormatter()
        if let value = iso.date(from: cleaned) {
            return value
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: cleaned)
    }
}

private enum HTMLContentExtractor {
    struct ArticleBodyResult {
        var body: String
        var rejectionReason: String?
    }

    static func metaDescription(from html: String) -> String? {
        extractMeta(named: "description", from: html)
            ?? extractMeta(property: "og:description", from: html)
    }

    static func bestTitle(from html: String) -> String? {
        if let title = firstMatch(in: html, pattern: #"<title[^>]*>(.*?)</title>"#, group: 1) {
            return normalize(title)
        }
        return extractMeta(property: "og:title", from: html)
    }

    static func articleBody(from html: String, fallback: String) -> String {
        articleBodyResult(from: html, fallback: fallback).body
    }

    static func articleBodyResult(from html: String, fallback: String) -> ArticleBodyResult {
        let paragraphs = extractParagraphs(from: html)
            .map(normalize)
            .filter { paragraph in
                paragraph.count >= 60
                    && !paragraph.localizedCaseInsensitiveContains("cookie")
                    && !paragraph.localizedCaseInsensitiveContains("javascript")
                    && !paragraph.localizedCaseInsensitiveContains("privacy")
            }

        let combined = paragraphs.joined(separator: "\n\n")
        if let cleaned = validatedArticleBody(from: combined) {
            return ArticleBodyResult(body: cleaned, rejectionReason: nil)
        }

        let fallbackText = normalize(fallback)
        if let cleaned = validatedArticleBody(from: fallbackText) {
            return ArticleBodyResult(body: cleaned, rejectionReason: nil)
        }

        let flattened = normalize(
            removingScriptAndStyleBlocks(from: html)
                .replacingOccurrences(of: "\n", with: " ")
        )
        if let cleaned = validatedArticleBody(from: flattened) {
            return ArticleBodyResult(body: cleaned, rejectionReason: nil)
        }

        return ArticleBodyResult(
            body: "",
            rejectionReason: bodyRejectionReason(for: combined.isEmpty ? flattened : combined)
        )
    }

    static func previewText(from text: String) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(900))
    }

    static func extractLinks(from html: String, matching pattern: String, limit: Int) -> [String] {
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex?.matches(in: html, options: [], range: nsRange) ?? []
        var results: [String] = []
        for match in matches {
            guard let range = Range(match.range, in: html) else { continue }
            let value = String(html[range])
            if !results.contains(value) {
                results.append(value)
            }
            if results.count >= limit {
                break
            }
        }
        return results
    }

    static func extractCandidateLinks(
        from html: String,
        baseURL: URL,
        kind: ConcreteSourceKind,
        limit: Int
    ) -> [String] {
        let resolvedLinks = extractResolvedLinks(from: html, baseURL: baseURL)
        let regexes = kind.discoveryPatterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
        let directMatches = kind.discoveryPatterns.flatMap { pattern in
            extractLinks(from: html, matching: pattern, limit: limit * 2)
        }
        let mergedLinks = resolvedLinks + directMatches
        var seen: Set<String> = []
        return mergedLinks.filter { link in
            guard let url = URL(string: link), !isAssetURL(url), kind.acceptsCandidateURL(url) else { return false }
            let lowered = link.lowercased()
            if lowered.contains("login") || lowered.contains("logout") || lowered.contains("search") || lowered.contains("passport") || lowered.contains("/special/") {
                return false
            }
            let nsRange = NSRange(link.startIndex..<link.endIndex, in: link)
            let matched = regexes.isEmpty || regexes.contains { $0.firstMatch(in: link, options: [], range: nsRange) != nil }
            guard matched else { return false }
            return seen.insert(link.normalizedMaterialURL).inserted
        }
        .prefix(limit)
        .map { $0 }
    }

    static func publishedAt(from html: String, url: URL) -> Date? {
        let metaPatterns = [
            #"property=["']article:published_time["'][^>]*content=["']([^"']+)["']"#,
            #"name=["']publishdate["'][^>]*content=["']([^"']+)["']"#,
            #"name=["']PubDate["'][^>]*content=["']([^"']+)["']"#,
            #"name=["']date["'][^>]*content=["']([^"']+)["']"#
        ]
        for pattern in metaPatterns {
            if let raw = firstMatch(in: html, pattern: pattern, group: 1), let date = FeedDateParser.parse(raw) {
                return date
            }
        }

        let absoluteString = url.absoluteString
        if let ymd = firstMatch(in: absoluteString, pattern: #"(20\d{2})[-/](\d{2})[-/](\d{2})"#, group: 0) {
            let normalized = ymd.replacingOccurrences(of: "/", with: "-")
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: normalized)
        }
        if let ymd = firstMatch(in: absoluteString, pattern: #"(20\d{2})(\d{2})(\d{2})"#, group: 0), ymd.count == 8 {
            let normalized = "\(ymd.prefix(4))-\(ymd.dropFirst(4).prefix(2))-\(ymd.suffix(2))"
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: normalized)
        }
        return nil
    }

    private static func extractParagraphs(from html: String) -> [String] {
        let cleanedHTML = removingScriptAndStyleBlocks(from: html)
        let regex = try? NSRegularExpression(pattern: #"<p\b[^>]*>(.*?)</p>"#, options: [.caseInsensitive, .dotMatchesLineSeparators])
        let nsRange = NSRange(cleanedHTML.startIndex..<cleanedHTML.endIndex, in: cleanedHTML)
        let matches = regex?.matches(in: cleanedHTML, options: [], range: nsRange) ?? []
        return matches.compactMap { match in
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: cleanedHTML) else { return nil }
            return String(cleanedHTML[range]).plainHTMLText
        }
    }

    private static func removingScriptAndStyleBlocks(from html: String) -> String {
        html
            .replacingOccurrences(of: #"<script\b[^>]*>.*?</script>"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<style\b[^>]*>.*?</style>"#, with: " ", options: [.regularExpression, .caseInsensitive])
    }

    private static func validatedArticleBody(from text: String) -> String? {
        let normalized = trimBoilerplate(in: normalize(text))
        guard normalized.count >= 180 else { return nil }
        guard bodyRejectionReason(for: normalized) == nil else { return nil }
        return normalized
    }

    private static func trimBoilerplate(in text: String) -> String {
        let markers = [
            "友情链接", "上一篇", "下一篇", "下一页", "上一页", "联系我们", "版权声明",
            "违法和不良信息举报", "互联网新闻信息服务许可证", "京ICP备", "京公网安备",
            "All Rights Reserved", "Copyright", "责任编辑", "打印本页", "关闭窗口"
        ]
        var trimmed = text
        for marker in markers {
            if let range = trimmed.range(of: marker), trimmed.distance(from: trimmed.startIndex, to: range.lowerBound) >= 240 {
                trimmed = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return trimmed
    }

    private static func bodyRejectionReason(for text: String) -> String? {
        let normalized = normalize(text)
        if normalized.isEmpty || normalized.count < 180 {
            return "正文长度不足。"
        }

        let suspiciousMarkers = [
            "document.", "window.", "addEventListener", "setTimeout", "function(", "javascript:",
            "var ", "const ", "let ", "fontSize", "deviceWidth", "appendChild", "innerHTML", "onclick"
        ]
        let suspiciousHitCount = suspiciousMarkers.reduce(into: 0) { partial, marker in
            if normalized.localizedCaseInsensitiveContains(marker) {
                partial += 1
            }
        }
        if suspiciousHitCount >= 2 {
            return "正文疑似脚本或页面模板。"
        }

        let navigationMarkers = [
            "首页", "频道", "栏目", "专题", "搜索", "投稿", "邮箱", "友情链接",
            "网站地图", "关于我们", "版权声明", "举报", "联系我们"
        ]
        let navigationHitCount = navigationMarkers.reduce(into: 0) { partial, marker in
            if normalized.contains(marker) {
                partial += 1
            }
        }
        if navigationHitCount >= 4 && sentenceCount(in: normalized) < 4 {
            return "正文疑似栏目页或导航页。"
        }

        guard sentenceCount(in: normalized) >= 3 else {
            return "正文句子过少，像是摘要或列表页。"
        }
        return nil
    }

    private static func sentenceCount(in text: String) -> Int {
        text.components(separatedBy: CharacterSet(charactersIn: "。！？.!?;；"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 18 }
            .count
    }

    private static func extractMeta(named name: String, from html: String) -> String? {
        firstMatch(
            in: html,
            pattern: #"<meta[^>]+name=["']\#(name)["'][^>]+content=["'](.*?)["'][^>]*>"#,
            group: 1
        ).map(normalize)
    }

    private static func extractMeta(property: String, from html: String) -> String? {
        firstMatch(
            in: html,
            pattern: #"<meta[^>]+property=["']\#(property)["'][^>]+content=["'](.*?)["'][^>]*>"#,
            group: 1
        ).map(normalize)
    }

    private static func firstMatch(in text: String, pattern: String, group: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, options: [], range: nsRange),
            match.numberOfRanges > group,
            let range = Range(match.range(at: group), in: text)
        else {
            return nil
        }
        return String(text[range]).plainHTMLText
    }

    private static func normalize(_ text: String) -> String {
        text
            .plainHTMLText
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractResolvedLinks(from html: String, baseURL: URL) -> [String] {
        let regex = try? NSRegularExpression(pattern: #"href=["']([^"']+)["']"#, options: [.caseInsensitive])
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex?.matches(in: html, options: [], range: nsRange) ?? []
        var results: [String] = []
        for match in matches {
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: html) else { continue }
            let rawValue = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawValue.isEmpty, !rawValue.hasPrefix("#"), !rawValue.hasPrefix("javascript:") else { continue }
            let resolved = URL(string: rawValue, relativeTo: baseURL)?.absoluteURL.absoluteString ?? rawValue
            if !results.contains(resolved) {
                results.append(resolved)
            }
        }
        return results
    }

    private static func isAssetURL(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        let blocked = [".css", ".js", ".png", ".jpg", ".jpeg", ".gif", ".svg", ".ico", ".pdf", ".zip", ".xml", ".rss"]
        return blocked.contains(where: path.hasSuffix)
    }
}

private struct OpenStaxBooksIndex: Decodable {
    var books: [OpenStaxBook]
}

private struct OpenStaxBook: Decodable {
    var title: String
    var bookState: String
    var webviewLink: String?
    var webviewRexLink: String?
    var subjects: [String]

    var preferredLink: URL? {
        if let webviewRexLink, let url = URL(string: webviewRexLink) {
            return url
        }
        if let webviewLink, let url = URL(string: webviewLink) {
            return url
        }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case title
        case bookState = "book_state"
        case webviewLink = "webview_link"
        case webviewRexLink = "webview_rex_link"
        case subjects
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: Key) throws -> String {
        if let value = try? decode(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decode(Double.self, forKey: key) {
            return String(value)
        }
        throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Expected string-like value.")
    }

    func decodeFlexibleInt(forKey key: Key) throws -> Int {
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }
        if let value = try? decode(String.self, forKey: key), let intValue = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return intValue
        }
        if let value = try? decode(Double.self, forKey: key) {
            return Int(value)
        }
        throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Expected int-like value.")
    }

    func decodeFlexibleDouble(forKey key: Key) throws -> Double {
        if let value = try? decode(Double.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? decode(String.self, forKey: key), let doubleValue = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return doubleValue
        }
        throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Expected double-like value.")
    }
}

private extension ReadingStructureType {
    init(normalizing raw: String) throws {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "causeeffect", "cause_effect", "因果":
            self = .causeEffect
        case "comparecontrast", "compare_contrast", "对比":
            self = .compareContrast
        case "problemsolution", "problem_solution", "问题解决", "问题-解决":
            self = .problemSolution
        case "mechanism", "机制", "机制说明":
            self = .mechanism
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Unsupported structureType: \(raw)")
            )
        }
    }
}

private extension ReadingClaimAnchor.Scope {
    init(normalizing raw: String) throws {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "global", "overall", "main", "总论点":
            self = .global
        case "local", "partial", "sub", "局部结论":
            self = .local
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Unsupported claim scope: \(raw)")
            )
        }
    }
}

private extension EvidenceClassificationItem.Role {
    init(normalizing raw: String) throws {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "claim", "conclusion", "thesis", "结论":
            self = .claim
        case "evidence", "support", "proof", "example", "data", "证据":
            self = .evidence
        case "background", "context", "背景":
            self = .background
        case "limitation", "limit", "limiting", "caveat", "concession", "restriction", "限制":
            self = .limitation
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Unsupported evidence role: \(raw)")
            )
        }
    }
}

private extension String {
    var plainHTMLText: String {
        var text = self
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        let entities: [String: String] = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&quot;": "\"",
            "&#39;": "'",
            "&apos;": "'",
            "&lt;": "<",
            "&gt;": ">",
            "&#8217;": "'",
            "&#8220;": "\"",
            "&#8221;": "\"",
            "&#8211;": "-",
            "&#8212;": "-"
        ]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedMaterialToken: String {
        lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: "", options: .regularExpression)
    }

    var normalizedMaterialURL: String {
        guard var components = URLComponents(string: self.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        components.fragment = nil
        components.query = nil
        let host = components.host?.lowercased() ?? ""
        let path = components.path.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(host)/\(path)"
    }

    var materialFingerprint: String {
        String(
            lowercased()
                .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: "", options: .regularExpression)
                .prefix(220)
        )
    }
}
