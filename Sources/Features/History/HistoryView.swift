import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var appModel
    @State private var moduleFilter: TrainingModule? = nil

    private var visibleSessions: [SessionResult] {
        appModel.sessions.filter { TrainingModule.allCases.contains($0.module) }
    }

    var body: some View {
        BDWorkbenchPage(title: "历史记录", subtitle: "只查看当前保留模块的训练结果。") {
            SurfaceCard(title: "全部记录", subtitle: "按阅读主线或支撑模块筛选。") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(label: "全部", isSelected: moduleFilter == nil) { moduleFilter = nil }
                        ForEach(TrainingModule.allCases) { mod in
                            FilterChip(label: mod.shortName, isSelected: moduleFilter == mod) { moduleFilter = mod }
                        }
                    }
                }

                let filtered = moduleFilter == nil ? visibleSessions : visibleSessions.filter { $0.module == moduleFilter }

                if filtered.isEmpty {
                    ContentUnavailableView(
                        "还没有训练记录",
                        systemImage: "clock.badge.questionmark",
                        description: Text("完成训练后，这里会显示新的阅读和支撑训练数据。")
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(filtered) { session in
                            sessionRow(session)
                        }
                    }
                }
            }
        }
    }

    private func sessionRow(_ session: SessionResult) -> some View {
        HStack(spacing: 14) {
            Image(systemName: session.module.systemImage)
                .foregroundStyle(moduleColor(session.module))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(session.module.shortName + summaryLabel(session))
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(BDColor.textPrimary)
                Text(appModel.formattedDate(session.endedAt))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            InfoPill(title: appModel.formattedDuration(session.duration), accent: moduleColor(session.module))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(BDColor.historyRow))
    }

    private func summaryLabel(_ session: SessionResult) -> String {
        switch session.metrics {
        case let .mainIdea(m):
            " \(m.isCorrect ? "命中主旨" : "主旨偏差")"
        case let .evidenceMap(m):
            " 准确率\(Int(m.accuracy * 100))%"
        case let .delayedRecall(m):
            " 命中\(m.recalledTargets)/\(m.totalTargets)"
        case let .schulte(m):
            " \(m.difficulty.shortLabel) 错误\(m.mistakeCount)"
        case let .nBack(m):
            " \(m.nLevel)-Back d'\(String(format: "%.1f", m.dPrime))"
        case let .visualSearch(m):
            " 斜率\(Int(m.searchSlope * 1000))ms"
        default:
            ""
        }
    }

    private func moduleColor(_ module: TrainingModule) -> Color {
        switch module {
        case .mainIdea:      BDColor.gold
        case .evidenceMap:   BDColor.teal
        case .delayedRecall: BDColor.green
        case .schulte:       BDColor.primaryBlue
        case .nBack:         BDColor.nBackAccent
        case .visualSearch:  BDColor.visualSearchAccent
        default:             BDColor.textSecondary
        }
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(isSelected ? BDColor.primaryBlue.opacity(0.12) : BDColor.panelSecondaryFill))
                .foregroundStyle(isSelected ? BDColor.primaryBlue : BDColor.textSecondary)
        }
        .buttonStyle(.plain)
    }
}
