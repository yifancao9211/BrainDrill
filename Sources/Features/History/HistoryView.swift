import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var appModel
    @State private var moduleFilter: TrainingModule? = nil

    private var visibleSessions: [SessionResult] {
        appModel.sessions.filter { TrainingModule.allCases.contains($0.module) }
    }

    var body: some View {
        BDWorkbenchPage(title: "历史", subtitle: "按模块筛选训练记录，快速回看最近状态。", maxContentWidth: BDMetrics.contentMaxAnalysisWidth) {
            SurfaceCard(title: "训练记录", subtitle: "按模块过滤后查看时长、日期和结果摘要。", accent: BDColor.teal) {
                HStack {
                    Picker("模块筛选", selection: $moduleFilter) {
                        Text("全部").tag(TrainingModule?.none)
                        Divider()
                        ForEach(TrainingModule.allCases) { mod in
                            Text(mod.shortName).tag(TrainingModule?.some(mod))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)

                    Spacer()
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
        BDInteractiveRow(accent: moduleColor(session.module)) {
            HStack(spacing: 12) {
                Image(systemName: session.module.systemImage)
                    .foregroundStyle(moduleColor(session.module))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.module.shortName)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(BDColor.textPrimary)
                    Text(summaryLabel(session))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(BDColor.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } trailing: {
            HStack(spacing: 14) {
                Text(appModel.formattedDate(session.endedAt))
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)
                    .frame(width: 120, alignment: .leading)
                InfoPill(title: appModel.formattedDuration(session.duration), accent: moduleColor(session.module))
            }
        }
    }

    private func summaryLabel(_ session: SessionResult) -> String {
        switch session.metrics {
        case let .mainIdea(m):
            m.isCorrect ? "命中主旨" : "主旨偏差"
        case let .evidenceMap(m):
            "准确率 \(Int(m.accuracy * 100))%"
        case let .delayedRecall(m):
            "命中 \(m.recalledTargets)/\(m.totalTargets)"
        case let .schulte(m):
            "\(m.difficulty.shortLabel) 错误 \(m.mistakeCount)"
        case let .nBack(m):
            "\(m.nLevel)-Back d' \(String(format: "%.1f", m.dPrime))"
        case let .visualSearch(m):
            "斜率 \(Int(m.searchSlope * 1000))ms"
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
