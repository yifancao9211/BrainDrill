import SwiftUI

struct EvidenceMapTrainingView: View {
    @Environment(AppModel.self) private var appModel

    @State private var passage: ReadingPassage?
    @State private var startedAt: Date?
    @State private var answeringStartedAt: Date?
    @State private var selections: [String: EvidenceClassificationItem.Role] = [:]
    @State private var claimLinks: [String: String] = [:]
    @State private var lastMetrics: EvidenceMapMetrics?

    private let accent = BDColor.teal

    var body: some View {
        BDWorkbenchPage(title: "结构证据", subtitle: "先分角色，再把证据连到它真正支撑的结论。") {
            if let passage {
                PassageStage(passage: passage, accent: accent) {
                    if answeringStartedAt == nil {
                        Button("开始结构标注") {
                            answeringStartedAt = Date()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        classificationStage(for: passage)
                    }
                }

                if let lastMetrics {
                    resultCard(metrics: lastMetrics, passage: passage)
                }
            } else {
                ReadingModuleIntroCard(
                    title: "抓结构",
                    subtitle: "训练你区分结论、证据、背景和限制，并识别证据到底支撑哪条结论。",
                    stats: [
                        ("累计次数", "\(sessionCount)", accent),
                        ("角色准确率", accuracyLabel, BDColor.green),
                        ("映射准确率", mappingAccuracyLabel, BDColor.warm),
                    ],
                    accent: accent,
                    actionTitle: "开始一组结构题"
                ) {
                    startNewSession()
                }
            }
        }
    }

    private var relevantSessions: [SessionResult] {
        appModel.sessions.filter { $0.module == .evidenceMap }
    }

    private var sessionCount: Int { relevantSessions.count }

    private var accuracyLabel: String {
        let metrics = relevantSessions.compactMap(\.evidenceMapMetrics)
        guard !metrics.isEmpty else { return "--" }
        let average = metrics.map(\.accuracy).reduce(0, +) / Double(metrics.count)
        return "\(Int(average * 100))%"
    }

    private var mappingAccuracyLabel: String {
        let metrics = relevantSessions.compactMap(\.evidenceMapMetrics).filter { $0.mappedItems > 0 }
        guard !metrics.isEmpty else { return "--" }
        let average = metrics.map(\.mappingAccuracy).reduce(0, +) / Double(metrics.count)
        return "\(Int(average * 100))%"
    }

    @ViewBuilder
    private func classificationStage(for passage: ReadingPassage) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SurfaceCard(
                title: "按句子拆结构",
                subtitle: stageSubtitle(for: passage)
            ) {
                if passage.requiresClaimMapping {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("本篇需要把证据连到它支撑的结论上：")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(BDColor.textPrimary)
                        ForEach(passage.claimAnchors) { anchor in
                            Text("\(anchor.scope.label)：\(anchor.text)")
                                .font(.system(.callout, design: .rounded))
                                .foregroundStyle(BDColor.textSecondary)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(accent.opacity(0.08))
                    )
                }

                ForEach(passage.evidenceItems) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(item.text)
                            .font(.system(.callout, design: .rounded))
                            .foregroundStyle(BDColor.textPrimary)

                        FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                            ForEach(EvidenceClassificationItem.Role.allCases) { role in
                                ReadingChipButton(
                                    title: role.label,
                                    isSelected: selections[item.id] == role,
                                    accent: accent
                                ) {
                                    selections[item.id] = role
                                }
                            }
                        }

                        if needsClaimMapping(for: item, in: passage) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("它最直接支撑或限定哪条结论？")
                                    .font(.system(.footnote, design: .rounded))
                                    .foregroundStyle(BDColor.textSecondary)
                                FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                                    ForEach(passage.claimAnchors) { anchor in
                                        ReadingChipButton(
                                            title: anchor.scope == .global ? "总论点" : "局部结论",
                                            isSelected: claimLinks[item.id] == anchor.id,
                                            accent: BDColor.warm
                                        ) {
                                            claimLinks[item.id] = anchor.id
                                        }
                                    }
                                }
                                if let selectedClaim = claimLinks[item.id],
                                   let anchor = passage.claimAnchors.first(where: { $0.id == selectedClaim }) {
                                    Text(anchor.text)
                                        .font(.system(.footnote, design: .rounded))
                                        .foregroundStyle(BDColor.textSecondary)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(BDColor.panelSecondaryFill.opacity(0.25))
                    )
                }

                Button("提交判分") {
                    submit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit(passage))
            }
        }
    }

    @ViewBuilder
    private func resultCard(metrics: EvidenceMapMetrics, passage: ReadingPassage) -> some View {
        SurfaceCard(title: "结构判分", subtitle: "先看角色判断，再看证据映射。") {
            HStack(spacing: 12) {
                MetricTile(label: "角色准确率", value: "\(Int(metrics.accuracy * 100))%", accent: BDColor.green)
                MetricTile(label: "映射", value: "\(metrics.correctMappings)/\(metrics.mappedItems)", accent: BDColor.warm)
                MetricTile(label: "误选", value: "\(metrics.falseSelections)", accent: BDColor.error)
            }

            if passage.requiresClaimMapping {
                Text(mappingFeedback(for: metrics, passage: passage))
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(BDColor.textSecondary)
            }

            Button("再来一组") {
                startNewSession()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func stageSubtitle(for passage: ReadingPassage) -> String {
        if passage.difficulty == 1 {
            return "难度 1：先把信息拆成结论、证据和背景。"
        }
        if passage.difficulty == 2 {
            return "难度 2：除了贴标签，还要判断证据在支撑哪条结论。"
        }
        return "难度 3：你需要同时处理限制条件和结论映射。"
    }

    private func startNewSession() {
        passage = ReadingDifficultyPlanner.nextPassage(for: .evidenceMap, sessions: appModel.sessions)
        startedAt = Date()
        answeringStartedAt = nil
        selections = [:]
        claimLinks = [:]
        lastMetrics = nil
    }

    private func needsClaimMapping(for item: EvidenceClassificationItem, in passage: ReadingPassage) -> Bool {
        passage.evidenceItemsNeedingMapping.contains(where: { $0.id == item.id })
    }

    private func canSubmit(_ passage: ReadingPassage) -> Bool {
        let rolesReady = passage.evidenceItems.allSatisfy { selections[$0.id] != nil }
        let mappingsReady = passage.evidenceItemsNeedingMapping.allSatisfy { claimLinks[$0.id] != nil }
        return rolesReady && mappingsReady
    }

    private func submit() {
        guard let passage, let startedAt, let answeringStartedAt else { return }
        let now = Date()
        let correctItems = passage.evidenceItems.filter { selections[$0.id] == $0.role }.count
        let falseSelections = passage.evidenceItems.filter {
            guard let selected = selections[$0.id] else { return false }
            return selected != $0.role
        }.count
        let mappedItems = passage.evidenceItemsNeedingMapping.count
        let correctMappings = passage.evidenceItemsNeedingMapping.filter { claimLinks[$0.id] == $0.supportsClaimID }.count
        let totalItems = max(passage.evidenceItems.count, 1)
        let metrics = EvidenceMapMetrics(
            passageID: passage.id,
            difficulty: passage.difficulty,
            totalItems: totalItems,
            correctItems: correctItems,
            falseSelections: falseSelections,
            accuracy: Double(correctItems) / Double(totalItems),
            mappedItems: mappedItems,
            correctMappings: correctMappings,
            mappingAccuracy: mappedItems > 0 ? Double(correctMappings) / Double(mappedItems) : 0,
            responseDuration: now.timeIntervalSince(answeringStartedAt)
        )
        appModel.recordEvidenceMapResult(metrics, startedAt: startedAt, endedAt: now)
        lastMetrics = metrics
    }

    private func mappingFeedback(for metrics: EvidenceMapMetrics, passage: ReadingPassage) -> String {
        if metrics.mappingAccuracy >= 0.8 {
            return "你已经不只是看懂句子，还能把证据挂回到总论点或局部结论上。"
        }

        if passage.mapsLimitationsToClaims {
            return "你对角色判断还可以，但高难度下的限制条件没有稳定地挂回总论点。"
        }

        return "下一步重点不是再读一遍句子，而是问自己：这句话到底在支撑哪条判断？"
    }
}

private struct FlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    init(horizontalSpacing: CGFloat, verticalSpacing: CGFloat) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? 600
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > maxWidth, currentRowWidth > 0 {
                totalHeight += currentRowHeight + verticalSpacing
                currentRowWidth = 0
                currentRowHeight = 0
            }
            currentRowWidth += size.width + horizontalSpacing
            currentRowHeight = max(currentRowHeight, size.height)
        }

        totalHeight += currentRowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var origin = CGPoint(x: bounds.minX, y: bounds.minY)
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > bounds.maxX, origin.x > bounds.minX {
                origin.x = bounds.minX
                origin.y += currentRowHeight + verticalSpacing
                currentRowHeight = 0
            }

            subview.place(
                at: origin,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            origin.x += size.width + horizontalSpacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}
