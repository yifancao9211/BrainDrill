import SwiftUI

/// 跨平台素材管理视图 —— 浏览内置素材、本地素材和逻辑题库。
struct MaterialsManageView: View {
    @Environment(AppModel.self) private var appModel
    @State private var searchText = ""
    @State private var selectedKind: MaterialKind = .reading
    @State private var deleteTarget: DeleteTarget?
    @State private var showDeleteConfirm = false
    @State private var previewPassage: ReadingPassage?
    @State private var previewSyllogism: SyllogismTrial?

    private enum MaterialKind: String, CaseIterable, Identifiable {
        case reading
        case logic

        var id: String { rawValue }

        var title: String {
            switch self {
            case .reading: "阅读素材"
            case .logic: "逻辑题库"
            }
        }
    }

    private enum DeleteTarget {
        case passage(String)
        case syllogism(String)
    }

    /// Unified row model for bundled and local passages.
    private struct PassageItem: Identifiable {
        let id: String
        let passage: ReadingPassage
        let isBundled: Bool
        let approvedAt: Date?
    }

    private var allItems: [PassageItem] {
        let approvedMap = Dictionary(uniqueKeysWithValues: appModel.approvedReadingPassages.map { ($0.passage.id, $0) })
        let items = ReadingPassageLibrary.all.map { passage in
            if let approved = approvedMap[passage.id] {
                return PassageItem(id: passage.id, passage: passage, isBundled: false, approvedAt: approved.approvedAt)
            } else {
                return PassageItem(id: passage.id, passage: passage, isBundled: true, approvedAt: nil)
            }
        }

        if searchText.isEmpty { return items }
        let query = searchText.lowercased()
        return items.filter {
            $0.passage.title.lowercased().contains(query)
            || $0.passage.domainTag.lowercased().contains(query)
            || $0.passage.body.lowercased().contains(query)
        }
    }

    private var syllogismItems: [SyllogismTrial] {
        let items = appModel.approvedSyllogismTrials.sorted {
            if $0.type.category.displayName == $1.type.category.displayName {
                return $0.type.displayName.localizedStandardCompare($1.type.displayName) == .orderedAscending
            }
            return $0.type.category.displayName.localizedStandardCompare($1.type.category.displayName) == .orderedAscending
        }

        if searchText.isEmpty { return items }
        let query = searchText.lowercased()
        return items.filter { trial in
            trial.id.lowercased().contains(query)
            || trial.type.displayName.lowercased().contains(query)
            || trial.type.category.displayName.lowercased().contains(query)
            || trial.abstractForm.lowercased().contains(query)
            || trial.premises.joined(separator: " ").lowercased().contains(query)
            || trial.conclusion.lowercased().contains(query)
        }
    }

    private var listTitle: String {
        switch selectedKind {
        case .reading:
            "阅读素材 (\(ReadingPassageLibrary.all.count))"
        case .logic:
            "逻辑题库 (\(appModel.approvedSyllogismTrials.count))"
        }
    }

    private var listSubtitle: String {
        switch selectedKind {
        case .reading:
            "内置题库和本地写入的全部阅读材料。"
        case .logic:
            "本地逻辑快判题；训练时优先从这里抽题。"
        }
    }

    var body: some View {
        BDWorkbenchPage(
            title: "素材管理",
            subtitle: "查看本地资料库；新增和更新由 CLI 直接写入 SQLite。",
            maxContentWidth: BDMetrics.contentMaxWorkbenchWidth
        ) {
            // MARK: - Material List

            SurfaceCard(
                title: listTitle,
                subtitle: listSubtitle,
                accent: selectedKind == .reading ? BDColor.gold : BDColor.syllogismAccent
            ) {
                VStack(spacing: 12) {
                    Picker("素材类型", selection: $selectedKind) {
                        ForEach(MaterialKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField(selectedKind == .reading ? "搜索标题、领域或内容" : "搜索类型、形式、前提或结论", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(BDColor.panelSecondaryFill))

                    switch selectedKind {
                    case .reading:
                        if allItems.isEmpty {
                            ContentUnavailableView(
                                searchText.isEmpty ? "没有素材" : "没有匹配的素材",
                                systemImage: searchText.isEmpty ? "tray" : "magnifyingglass",
                                description: Text(searchText.isEmpty
                                    ? "使用 braindrillctl 写入素材后会显示在这里。"
                                    : "尝试其他关键词。")
                            )
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(allItems) { item in
                                    passageRow(item)
                                }
                            }
                        }

                    case .logic:
                        if syllogismItems.isEmpty {
                            ContentUnavailableView(
                                searchText.isEmpty ? "没有逻辑题" : "没有匹配的逻辑题",
                                systemImage: searchText.isEmpty ? "tray" : "magnifyingglass",
                                description: Text(searchText.isEmpty
                                    ? "使用 braindrillctl 写入逻辑题后会显示在这里。"
                                    : "尝试其他关键词。")
                            )
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(syllogismItems) { trial in
                                    syllogismRow(trial)
                                }
                            }
                        }
                    }
                }
            }
        }
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) {
                switch deleteTarget {
                case .passage(let id):
                    if let passage = appModel.approvedReadingPassages.first(where: { $0.id == id }) {
                        appModel.deleteApprovedPassage(passage)
                    }
                case .syllogism(let id):
                    if let trial = appModel.approvedSyllogismTrials.first(where: { $0.id == id }) {
                        appModel.deleteApprovedSyllogismTrial(trial)
                    }
                case nil:
                    break
                }
                deleteTarget = nil
            }
            Button("取消", role: .cancel) {
                deleteTarget = nil
            }
        } message: {
            Text("确定要删除该素材吗？此操作不可撤销。")
        }
        .sheet(item: $previewPassage) { passage in
            PassageDetailSheet(passage: passage)
        }
        .sheet(item: $previewSyllogism) { trial in
            SyllogismTrialDetailSheet(trial: trial)
        }
        .onAppear {
            appModel.reloadApprovedMaterialsFromStore()
        }
    }

    // MARK: - Row

    private func passageRow(_ item: PassageItem) -> some View {
        Button {
            previewPassage = item.passage
        } label: {
            BDInteractiveRow(accent: difficultyColor(item.passage.difficulty)) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.passage.title)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(BDColor.textPrimary)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            InfoPill(title: item.passage.domainTag, accent: BDColor.teal)
                            InfoPill(title: "难度 \(item.passage.difficulty)", accent: difficultyColor(item.passage.difficulty))
                            if item.isBundled {
                                InfoPill(title: "内置", accent: BDColor.primaryBlue)
                            } else {
                                InfoPill(title: "本地", accent: BDColor.warm)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } trailing: {
                HStack(spacing: 12) {
                    Image(systemName: "chevron.right")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.tertiary)

                    if !item.isBundled {
                        Button {
                            deleteTarget = .passage(item.id)
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(.body, weight: .medium))
                                .foregroundStyle(BDColor.error)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func syllogismRow(_ trial: SyllogismTrial) -> some View {
        Button {
            previewSyllogism = trial
        } label: {
            BDInteractiveRow(accent: trial.isValid ? BDColor.green : BDColor.error) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(trial.type.displayName)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(BDColor.textPrimary)
                            .lineLimit(1)

                        Text(trial.abstractForm)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(BDColor.syllogismAccent)
                            .lineLimit(1)
                    }

                    Text("∴ \(trial.conclusion)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(BDColor.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        InfoPill(title: trial.type.category.displayName, accent: BDColor.syllogismAccent)
                        InfoPill(title: trial.isValid ? "有效" : "无效", accent: trial.isValid ? BDColor.green : BDColor.error)
                        InfoPill(title: "\(trial.premises.count) 条前提", accent: BDColor.primaryBlue)
                        if trial.hasUnverifiedPremise {
                            InfoPill(title: "含未证实前提", accent: BDColor.warm)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } trailing: {
                HStack(spacing: 12) {
                    Image(systemName: "chevron.right")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.tertiary)

                    Button {
                        deleteTarget = .syllogism(trial.id)
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(BDColor.error)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func difficultyColor(_ difficulty: Int) -> Color {
        switch difficulty {
        case 1: BDColor.green
        case 2: BDColor.warm
        default: BDColor.error
        }
    }
}

private struct SyllogismTrialDetailSheet: View {
    let trial: SyllogismTrial
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            InfoPill(title: trial.type.category.displayName, accent: BDColor.syllogismAccent)
                            InfoPill(title: trial.isValid ? "有效推理" : "无效推理", accent: trial.isValid ? BDColor.green : BDColor.error)
                            if trial.hasUnverifiedPremise {
                                InfoPill(title: "含未证实前提", accent: BDColor.warm)
                            }
                        }

                        Text(trial.id)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(BDColor.textSecondary)
                            .textSelection(.enabled)
                    }

                    Divider()

                    sectionHeader("前提", icon: "list.number")
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(trial.premises.enumerated()), id: \.offset) { index, premise in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(BDColor.syllogismAccent))

                                Text(premise)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(BDColor.textPrimary)
                                    .textSelection(.enabled)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 10).fill(BDColor.panelSecondaryFill))
                        }
                    }

                    sectionHeader("结论", icon: "arrow.turn.down.right")
                    Text(trial.conclusion)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(BDColor.textPrimary)
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(BDColor.panelSecondaryFill))

                    Divider()

                    sectionHeader("逻辑形式", icon: "function")
                    Text(trial.abstractForm)
                        .font(.system(.body, design: .monospaced, weight: .semibold))
                        .foregroundStyle(BDColor.syllogismAccent)
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(BDColor.syllogismAccent.opacity(0.08)))

                    sectionHeader("判定说明", icon: "checklist")
                    Text(trial.explanation)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(BDColor.textPrimary)
                        .textSelection(.enabled)
                        .lineSpacing(5)

                    if !trial.detailedExplanation.isEmpty {
                        Divider()

                        sectionHeader("详细说明", icon: "doc.text.magnifyingglass")
                        Text(trial.detailedExplanation)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(BDColor.textPrimary)
                            .textSelection(.enabled)
                            .lineSpacing(5)
                    }
                }
                .padding(24)
                .frame(maxWidth: 800)
            }
            .navigationTitle(trial.type.displayName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 700, idealWidth: 800, minHeight: 600, idealHeight: 720)
        #endif
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(BDColor.syllogismAccent)
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(BDColor.textPrimary)
        }
    }
}
