import SwiftUI

struct MaterialsWorkbenchView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var previewCandidate: MaterialCandidate?

    private var approvedRows: [ApprovedMaterialRow] {
        appModel.approvedReadingPassages
            .sorted { $0.approvedAt > $1.approvedAt }
            .map {
                ApprovedMaterialRow(
                    id: $0.id,
                    title: $0.passage.title,
                    source: $0.sourceArticle.sourceKind.title,
                    difficulty: $0.passage.difficulty,
                    score: Int($0.score.rounded()),
                    approvedAt: appModel.formattedDate($0.approvedAt),
                    url: URL(string: $0.sourceArticle.url)
                )
            }
    }

    var body: some View {
        BDWorkbenchPage(
            title: "素材工作台",
            subtitle: "自动抓开放来源，交给 AI 清洗，再人工审核入库。",
            maxContentWidth: BDMetrics.contentMaxWorkbenchWidth
        ) {
            LazyVStack(spacing: 16) {
                sourceDirectoryCard
                controlCard
                candidatesCard
                approvedMaterialsCard
            }
        }
        .sheet(item: $previewCandidate) { candidate in
            MaterialCandidatePreviewSheet(candidate: candidate)
        }
    }

    private var sourceDirectoryCard: some View {
        SurfaceCard(title: "来源目录", subtitle: "顶层收敛为党政学习与学科资料库；每个目录下挂多个具体来源。") {
            LazyVStack(spacing: 14) {
                ForEach(ContentDirectoryKind.allCases) { directory in
                    let configs = directoryConfigs(for: directory)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(directory.title)
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundStyle(BDColor.textPrimary)
                                Text(directory.subtitle)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(BDColor.textSecondary)
                            }
                            Spacer()
                            InfoPill(title: "\(configs.filter(\.isEnabled).count)/\(configs.count) 已启用", accent: accent(for: directory))
                        }

                        if directory == .partyStateStudy {
                            LazyVStack(spacing: 8) {
                                ForEach(configs) { config in
                                    sourceRow(config)
                                }
                            }
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(DisciplineGroup.allCases) { group in
                                    let groupConfigs = configsForGroup(group)
                                    if !groupConfigs.isEmpty {
                                        DisclosureGroup {
                                            LazyVStack(spacing: 8) {
                                                ForEach(groupConfigs) { config in
                                                    sourceRow(config)
                                                }
                                            }
                                            .padding(.top, 10)
                                        } label: {
                                            HStack {
                                                Text(group.title)
                                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                                    .foregroundStyle(BDColor.textPrimary)
                                                Spacer()
                                                Text(tagsSummary(for: groupConfigs))
                                                    .font(.system(.caption2, design: .rounded))
                                                    .foregroundStyle(BDColor.textTertiary)
                                            }
                                        }
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(BDColor.panelSecondaryFill.opacity(0.22))
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(BDColor.panelSecondaryFill.opacity(0.34))
                    )
                }
            }
        }
    }

    private var controlCard: some View {
        SurfaceCard(title: "采集控制", subtitle: "先抓取、再清洗、最后进入待审核候选。") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    MetricTile(label: "启用来源", value: "\(appModel.sourceConfigs.filter(\.isEnabled).count)", accent: BDColor.primaryBlue)
                    MetricTile(label: "待审核", value: "\(appModel.pendingMaterialCandidates.count)", accent: BDColor.gold)
                    MetricTile(label: "正式材料", value: "\(appModel.approvedReadingPassages.count)", accent: BDColor.green)
                    MetricTile(label: "阈值", value: "\(Int(appModel.settings.materialsCandidateThreshold))", accent: BDColor.teal)
                }

                HStack(spacing: 12) {
                    Button {
                        appModel.runMaterialsHarvest()
                    } label: {
                        HStack(spacing: 8) {
                            if appModel.isMaterialsRunInProgress {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(appModel.isMaterialsRunInProgress ? "抓取中..." : "抓取并清洗候选")
                        }
                        .frame(minWidth: 180)
                    }
                    .buttonStyle(BDPrimaryButton(accent: BDColor.warm))
                    .disabled(appModel.isMaterialsRunInProgress || appModel.sourceConfigs.allSatisfy { !$0.isEnabled })

                    Button("一键清空日志与缓存") {
                        appModel.clearAllMaterialsData()
                    }
                    .buttonStyle(BDSecondaryButton(accent: BDColor.error))
                    .disabled(appModel.isMaterialsRunInProgress)

                    if let latest = appModel.latestMaterialRun {
                        Text("上次执行：\(appModel.formattedDate(latest.endedAt))，文章 \(latest.articleCount) 篇，候选 \(latest.candidateCount) 条。")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(BDColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Text(appModel.materialsStatusMessage)
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(BDColor.textPrimary)

                if appModel.isMaterialsRunInProgress {
                    liveDashboard
                } else if let latest = appModel.latestMaterialRun {
                    BDTableSection(title: "最近执行日志", subtitle: "按来源快速查看结果与异常。") {
                        VStack(spacing: 8) {
                            ForEach(latest.sourceSummaries) { summary in
                                BDInteractiveRow(accent: statusColor(summary.status)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 8) {
                                            Text(summary.sourceKind.title)
                                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                                .foregroundStyle(BDColor.textPrimary)
                                            InfoPill(title: summary.status?.label ?? "未运行", accent: statusColor(summary.status))
                                        }
                                        Text(summary.errorMessage ?? summary.detailMessage ?? "抓取 \(summary.articleCount) 篇，候选 \(summary.candidateCount) 条。")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(summary.errorMessage == nil ? BDColor.textTertiary : BDColor.error)
                                            .lineLimit(2)
                                            .textSelection(.enabled)
                                    }
                                } trailing: {
                                    Text("\(summary.articleCount)/\(summary.candidateCount)")
                                        .font(.system(.caption2, design: .monospaced, weight: .semibold))
                                        .foregroundStyle(BDColor.textSecondary)
                                }
                            }

                            ForEach(Array(latest.errorMessages.prefix(4).enumerated()), id: \.offset) { _, message in
                                Text(message)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(BDColor.error)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var liveDashboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(appModel.materialsPipelineProgress?.phase ?? "环境初始化...")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(BDColor.teal)
                Spacer()
                Text("\(Int((appModel.materialsPipelineProgress?.fractionCompleted ?? 0) * 100))%")
                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                    .foregroundStyle(BDColor.teal)
            }
            
            ProgressView(value: appModel.materialsPipelineProgress?.fractionCompleted ?? 0)
                .tint(BDColor.teal)
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(appModel.materialsLiveLogs.enumerated()), id: \.offset) { index, log in
                            Text(log)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(log.contains("⚠️") || log.contains("失败") ? BDColor.error : BDColor.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                    .padding(12)
                }
                .frame(height: 180)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(BDColor.overlayFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(BDColor.borderStrong, lineWidth: 1)
                )
                .onChange(of: appModel.materialsLiveLogs.count) { _, newCount in
                    if newCount > 0 {
                        if reduceMotion {
                            proxy.scrollTo(newCount - 1, anchor: .bottom)
                        } else {
                            withAnimation(.easeOut(duration: 0.16)) {
                                proxy.scrollTo(newCount - 1, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BDColor.panelSecondaryFill.opacity(0.5))
                .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
        )
    }

    private var candidatesCard: some View {
        SurfaceCard(title: "候选材料", subtitle: "先看评分和风险，再决定是否入库。") {
            if appModel.pendingMaterialCandidates.isEmpty {
                emptyState("还没有待审核候选。点击上方按钮开始抓取。")
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(appModel.pendingMaterialCandidates) { candidate in
                        candidateCard(candidate)
                    }
                }
            }
        }
    }

    private var approvedMaterialsCard: some View {
        SurfaceCard(title: "正式材料", subtitle: "审核通过后会立即参与阅读模块抽题。") {
            if appModel.approvedReadingPassages.isEmpty {
                emptyState("正式材料库目前只有内置题库，本地还没有新增素材。")
            } else {
                BDTableSection(title: "已入库材料", subtitle: "优先看标题、来源、难度和审核时间。") {
                    Table(Array(approvedRows.prefix(24))) {
                        TableColumn("标题") { row in
                            Text(row.title)
                                .foregroundStyle(BDColor.textPrimary)
                                .lineLimit(2)
                        }
                        .width(min: 260, ideal: 360)

                        TableColumn("来源") { row in
                            if let url = row.url {
                                Link(row.source, destination: url)
                                    .foregroundStyle(BDColor.primaryBlue)
                            } else {
                                Text(row.source)
                                    .foregroundStyle(BDColor.textSecondary)
                            }
                        }
                        .width(min: 100, ideal: 120)

                        TableColumn("难度") { row in
                            Text("\(row.difficulty)")
                                .font(.system(.footnote, design: .monospaced, weight: .semibold))
                                .foregroundStyle(BDColor.textPrimary)
                        }
                        .width(56)

                        TableColumn("评分") { row in
                            Text("\(row.score)")
                                .font(.system(.footnote, design: .monospaced, weight: .semibold))
                                .foregroundStyle(BDColor.green)
                        }
                        .width(64)

                        TableColumn("审核时间") { row in
                            Text(row.approvedAt)
                                .foregroundStyle(BDColor.textSecondary)
                        }
                        .width(min: 126, ideal: 150)
                    }
                    .frame(minHeight: 280, maxHeight: 340)
                    .tableStyle(.inset(alternatesRowBackgrounds: false))
                    .scrollContentBackground(.hidden)
                }
            }
        }
    }

    private func sourceRow(_ config: ContentSourceConfig) -> some View {
        BDInteractiveRow(accent: color(for: config.kind)) {
            HStack(spacing: 14) {
                Circle()
                    .fill(color(for: config.kind).opacity(0.16))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: config.kind.iconName)
                            .font(.system(.callout, weight: .semibold))
                            .foregroundStyle(color(for: config.kind))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(config.kind.title)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(BDColor.textPrimary)
                        InfoPill(title: config.kind.sourceDomainLabel, accent: color(for: config.kind))
                        InfoPill(title: config.kind.cadence.label, accent: cadenceColor(config.kind.cadence))
                    }
                    Text(config.kind.subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(BDColor.textSecondary)
                        .lineLimit(2)
                    Text(sourceStatusText(for: config))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(sourceStatusColor(for: config))
                        .lineLimit(2)
                }
            }
        } trailing: {
            Toggle("", isOn: Binding(
                get: { config.isEnabled },
                set: { appModel.updateSourceEnabled(config.kind, isEnabled: $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .bdFocusRing(cornerRadius: 10)
        }
    }

    private func candidateCard(_ candidate: MaterialCandidate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(candidate.displayTitle)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(BDColor.textPrimary)
                    Text("\(candidate.sourceArticle.sourceKind.title) · \(candidate.generatedPassage?.structureType.label ?? "待定结构") · 难度 \(candidate.generatedPassage?.difficulty ?? candidate.suggestedDifficulty)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(BDColor.textSecondary)
                    if let publishedAt = candidate.sourceArticle.publishedAt {
                        Text("来源时间：\(appModel.formattedDate(publishedAt))")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(BDColor.textTertiary)
                    }
                    if candidate.displayTitle != candidate.sourceArticle.title {
                        Text("原始标题：\(candidate.sourceArticle.title)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(BDColor.textTertiary)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    InfoPill(title: candidate.status.label, accent: badgeColor(for: candidate.status))
                    Text("\(Int(candidate.score)) 分")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(candidate.score >= appModel.settings.materialsCandidateThreshold ? BDColor.green : BDColor.warm)
                }
            }

            Text(candidate.displaySummary)
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(BDColor.textPrimary)
                .lineLimit(6)

            if !candidate.failureReasons.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(candidate.failureReasons.enumerated()), id: \.offset) { _, reason in
                        Text(reason)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(BDColor.error)
                    }
                }
            }

            if !candidate.resolvedDebugLogs.isEmpty {
                DisclosureGroup {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(candidate.resolvedDebugLogs.suffix(8).enumerated()), id: \.offset) { _, log in
                            Text(log)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(BDColor.textTertiary)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                } label: {
                    Text("调试日志")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(BDColor.textSecondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(BDColor.panelSecondaryFill.opacity(0.22))
                )
            }

            HStack(spacing: 10) {
                Button("预览文章题目和答案") {
                    previewCandidate = candidate
                }
                .buttonStyle(BDSecondaryButton(accent: BDColor.primaryBlue))

                if let url = URL(string: candidate.sourceArticle.url) {
                    Link("查看来源", destination: url)
                        .font(.system(.caption, design: .rounded))
                }

                Spacer()

                Button("重新清洗") {
                    appModel.reprocessMaterialCandidate(candidate.id)
                }
                .buttonStyle(BDSecondaryButton(accent: BDColor.teal))
                .disabled(appModel.isMaterialsRunInProgress)

                Button("退回") {
                    appModel.rejectMaterialCandidate(candidate.id)
                }
                .buttonStyle(BDSecondaryButton(accent: BDColor.error))
                .disabled(appModel.isMaterialsRunInProgress)

                Button("通过入库") {
                    appModel.approveMaterialCandidate(candidate.id)
                }
                .buttonStyle(BDPrimaryButton(accent: BDColor.green))
                .disabled(appModel.isMaterialsRunInProgress || !candidate.canApprove)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BDColor.panelSecondaryFill.opacity(0.34))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BDColor.borderSubtle, lineWidth: 0.8)
        )
    }

    private func directoryConfigs(for directory: ContentDirectoryKind) -> [ContentSourceConfig] {
        appModel.sourceConfigs
            .filter { $0.kind.directory == directory }
            .sorted { $0.kind.title.localizedCompare($1.kind.title) == .orderedAscending }
    }

    private func configsForGroup(_ group: DisciplineGroup) -> [ContentSourceConfig] {
        directoryConfigs(for: .disciplineLibrary)
            .filter { $0.kind.primaryGroup == group }
    }

    private func tagsSummary(for configs: [ContentSourceConfig]) -> String {
        let tags = configs.flatMap(\.kind.disciplineTags).map(\.title)
        let unique = Array(NSOrderedSet(array: tags)) as? [String] ?? []
        return unique.prefix(5).joined(separator: "、")
    }

    private func sourceStatusText(for config: ContentSourceConfig) -> String {
        if let lastError = config.lastError, !lastError.isEmpty {
            return lastError
        }
        if let lastCompletedAt = config.lastCompletedAt {
            return "最近完成：\(appModel.formattedDate(lastCompletedAt)) · \(config.lastStatus?.label ?? "正常")"
        }
        return config.kind.disciplineTags.map(\.title).prefix(4).joined(separator: " · ")
    }

    private func sourceStatusColor(for config: ContentSourceConfig) -> Color {
        if let lastError = config.lastError, !lastError.isEmpty {
            return BDColor.error
        }
        if config.lastCompletedAt != nil {
            return statusColor(config.lastStatus)
        }
        return BDColor.textTertiary
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.system(.callout, design: .rounded))
            .foregroundStyle(BDColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private func accent(for directory: ContentDirectoryKind) -> Color {
        switch directory {
        case .partyStateStudy:
            BDColor.warm
        case .disciplineLibrary:
            BDColor.teal
        }
    }

    private func color(for kind: ConcreteSourceKind) -> Color {
        switch kind.directory {
        case .partyStateStudy:
            return BDColor.warm
        case .disciplineLibrary:
            switch kind {
            case .ourWorldInData, .worldBank, .unesco, .oecd:
                return BDColor.teal
            case .nasa:
                return BDColor.gold
            case .cdc, .nih, .brainFacts:
                return BDColor.green
            default:
                return BDColor.primaryBlue
            }
        }
    }

    private func cadenceColor(_ cadence: SourceCadence) -> Color {
        switch cadence {
        case .timely:
            BDColor.green
        case .evergreen:
            BDColor.primaryBlue
        case .protectedAttempt:
            BDColor.warm
        }
    }

    private func badgeColor(for status: MaterialCandidateStatus) -> Color {
        switch status {
        case .pending:
            BDColor.gold
        case .rejected:
            BDColor.error
        case .approved:
            BDColor.green
        }
    }

    private func statusColor(_ status: SourceHealthStatus?) -> Color {
        switch status {
        case .healthy:
            BDColor.green
        case .timeout, .networkError, .httpError:
            BDColor.error
        case .protectedSource:
            BDColor.warm
        case .parseFailure, .emptyContent:
            BDColor.gold
        case .idle, .none:
            BDColor.textTertiary
        }
    }
}

private struct ApprovedMaterialRow: Identifiable {
    let id: String
    let title: String
    let source: String
    let difficulty: Int
    let score: Int
    let approvedAt: String
    let url: URL?
}

private struct MaterialCandidatePreviewSheet: View {
    let candidate: MaterialCandidate
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("来源信息") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(candidate.displayTitle)
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(BDColor.textPrimary)
                            Text("\(candidate.sourceArticle.sourceKind.title) · \(candidate.sourceArticle.domainTag) · \(Int(candidate.score)) 分")
                                .font(.system(.callout, design: .rounded))
                                .foregroundStyle(BDColor.textSecondary)
                            if let url = URL(string: candidate.sourceArticle.url) {
                                Link(candidate.sourceArticle.url, destination: url)
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                    }

                    section("原文全文") {
                        Text((candidate.sourceArticle.sourceText?.isEmpty == false ? candidate.sourceArticle.sourceText! : candidate.sourceArticle.excerpt))
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(BDColor.textPrimary)
                            .textSelection(.enabled)
                    }

                    section("训练正文") {
                        Text(candidate.generatedPassage?.body ?? candidate.generatedSummary)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(BDColor.textPrimary)
                            .textSelection(.enabled)
                    }

                    if let passage = candidate.generatedPassage {
                        section("主旨题与答案") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(passage.mainIdeaOptions.enumerated()), id: \.offset) { index, option in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(index + 1).")
                                            .font(.system(.callout, design: .rounded, weight: .semibold))
                                            .foregroundStyle(index == passage.mainIdeaAnswerIndex ? BDColor.green : BDColor.textSecondary)
                                        Text(option)
                                            .font(.system(.callout, design: .rounded))
                                            .foregroundStyle(BDColor.textPrimary)
                                    }
                                }
                                Text("理想主旨：\(passage.mainIdeaRubric.idealSummary)")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(BDColor.textSecondary)
                                Text("关键词：\(passage.mainIdeaRubric.keywords.joined(separator: "、"))")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(BDColor.textSecondary)
                            }
                        }

                        section("结论与证据") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(passage.claimAnchors) { claim in
                                    Text("结论[\(claim.scope.label)] \(claim.text)")
                                        .font(.system(.callout, design: .rounded, weight: .semibold))
                                        .foregroundStyle(BDColor.textPrimary)
                                }
                                Divider()
                                ForEach(passage.evidenceItems) { item in
                                    Text("\(item.role.label)：\(item.text)\(item.supportsClaimID.map { " -> \($0)" } ?? "")")
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(BDColor.textSecondary)
                                }
                            }
                        }

                        section("延迟回忆答案") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(passage.recallPrompts) { prompt in
                                    Text("\(prompt.isTarget ? "真" : "假")：\(prompt.text)")
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(prompt.isTarget ? BDColor.green : BDColor.warm)
                                }
                                Text("关键词：\(passage.recallKeywords.joined(separator: "、"))")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(BDColor.textSecondary)
                            }
                        }
                    }

                    section("风险与日志") {
                        VStack(alignment: .leading, spacing: 8) {
                            if candidate.failureReasons.isEmpty {
                                Text("当前没有结构风险。")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(BDColor.textSecondary)
                            } else {
                                ForEach(Array(candidate.failureReasons.enumerated()), id: \.offset) { _, reason in
                                    Text(reason)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(BDColor.error)
                                }
                            }
                            ForEach(Array(candidate.resolvedDebugLogs.enumerated()), id: \.offset) { _, log in
                                Text(log)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(BDColor.textTertiary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(BDColor.appBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .frame(minWidth: 760, minHeight: 720)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(BDColor.textPrimary)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(BDColor.panelSecondaryFill.opacity(0.34))
                )
        }
    }
}
