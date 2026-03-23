import SwiftUI

enum BDShellMode {
    case workbench
    case trainingFocus
}

enum BDStageTone {
    case neutral
    case memory
    case reaction
    case visual
    case reading
    case analytics
}

struct ModulePresentationProfile {
    let accent: Color
    let shellMode: BDShellMode
    let tone: BDStageTone
    let subtitle: String
}

struct BDScreenContextBar: View {
    let route: AppRoute
    let status: String
    let isTrainingActive: Bool

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: route.systemImage)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(route.presentationProfile.accent)
                    .frame(width: 32, height: 32)
                    .background(route.presentationProfile.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(route.title)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(BDColor.textPrimary)
                    Text(isTrainingActive ? status : route.presentationProfile.subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(BDColor.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                if route.isModule {
                    InfoPill(title: isTrainingActive ? "训练中" : "待开始", accent: isTrainingActive ? route.presentationProfile.accent : BDColor.textSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .bdPanelSurface(.primary, cornerRadius: 18)
    }
}
