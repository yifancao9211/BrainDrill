import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        SurfaceCard(title: "历史记录", subtitle: "查看每轮训练的时间、难度与错误次数。") {
            if appModel.history.isEmpty {
                ContentUnavailableView(
                    "还没有训练记录",
                    systemImage: "clock.badge.questionmark",
                    description: Text("先完成一轮舒尔特训练，这里会开始累积历史数据。")
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(appModel.history) { result in
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.difficulty.displayName)
                                    .font(.system(.headline, design: .rounded))
                                Text(appModel.formattedDate(result.endedAt))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            InfoPill(title: "错误 \(result.mistakeCount)", accent: Color(red: 0.72, green: 0.34, blue: 0.25))
                            InfoPill(title: appModel.formattedDuration(result.duration), accent: Color(red: 0.17, green: 0.41, blue: 0.72))
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.56))
                        )
                    }
                }
            }
        }
    }
}
