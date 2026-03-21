import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var appModel
    @State private var moduleFilter: TrainingModule? = nil

    var body: some View {
        SurfaceCard(title: "历史记录", subtitle: "所有训练模块的完成记录。") {
            HStack(spacing: 8) {
                FilterChip(label: "全部", isSelected: moduleFilter == nil) { moduleFilter = nil }
                ForEach(TrainingModule.allCases) { mod in
                    FilterChip(label: mod.shortName, isSelected: moduleFilter == mod) { moduleFilter = mod }
                }
            }

            let filtered = moduleFilter == nil ? appModel.sessions : appModel.sessions.filter { $0.module == moduleFilter }

            if filtered.isEmpty {
                ContentUnavailableView(
                    "还没有训练记录",
                    systemImage: "clock.badge.questionmark",
                    description: Text("完成训练后，这里会累积历史数据。")
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

    private func sessionRow(_ session: SessionResult) -> some View {
        HStack(spacing: 14) {
            Image(systemName: session.module.systemImage)
                .foregroundStyle(moduleColor(session.module))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(session.module.shortName + summaryLabel(session))
                    .font(.system(.headline, design: .rounded))
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
        case let .schulte(m):         " \(m.difficulty.shortLabel) 错误\(m.mistakeCount)"
        case let .flanker(m):         " 冲突\(Int(m.conflictCost * 1000))ms"
        case let .goNoGo(m):          " d'\(String(format: "%.1f", m.dPrime))"
        case let .nBack(m):           " \(m.nLevel)-Back d'\(String(format: "%.1f", m.dPrime))"
        case let .digitSpan(m):       " 广度\(max(m.maxSpanForward, m.maxSpanBackward))"
        case let .choiceRT(m):        " RT\(Int(m.medianRT * 1000))ms"
        case let .changeDetection(m): " d'\(String(format: "%.1f", m.dPrime))"
        case let .visualSearch(m):    " 斜率\(Int(m.searchSlope * 1000))ms"
        }
    }

    private func moduleColor(_ module: TrainingModule) -> Color {
        switch module {
        case .schulte:         BDColor.primaryBlue
        case .flanker:         BDColor.flankerAccent
        case .goNoGo:          BDColor.goNoGoAccent
        case .nBack:           BDColor.nBackAccent
        case .digitSpan:       BDColor.digitSpanAccent
        case .choiceRT:        BDColor.choiceRTAccent
        case .changeDetection: BDColor.changeDetectionAccent
        case .visualSearch:    BDColor.visualSearchAccent
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
                .background(Capsule().fill(isSelected ? BDColor.primaryBlue.opacity(0.15) : BDColor.barTrack))
                .foregroundStyle(isSelected ? BDColor.primaryBlue : .secondary)
        }
        .buttonStyle(.plain)
    }
}
