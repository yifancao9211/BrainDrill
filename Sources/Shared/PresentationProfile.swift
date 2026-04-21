import SwiftUI

enum BDShellMode {
    case workspace
    case training
}

enum BDStageTone {
    case neutral
    case reading
    case logic
    case attention
    case inhibition
    case memory
    case speed
    case analytics
}

enum BDNavigationCluster: String {
    case controlCenter
    case trainingLibrary
    case analysis
    case materials
    case settings
}

struct ModulePresentationProfile {
    let accent: Color
    let shellMode: BDShellMode
    let tone: BDStageTone
    let cluster: BDNavigationCluster
    let subtitle: String
    let shortDescription: String
}

struct BDScreenContextBar: View {
    let route: AppRoute
    let status: String
    let isTrainingActive: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: route.systemImage)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(route.presentationProfile.accent)

            VStack(alignment: .leading, spacing: 1) {
                Text(route.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(BDColor.textPrimary)
                Text(isTrainingActive ? status : route.presentationProfile.shortDescription)
                    .font(.system(.caption2))
                    .foregroundStyle(BDColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if route.isModule {
                Text(isTrainingActive ? "训练中" : "准备态")
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(isTrainingActive ? route.presentationProfile.accent : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill((isTrainingActive ? route.presentationProfile.accent : Color.secondary).opacity(0.1))
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .bdPanelSurface(.primary, cornerRadius: BDMetrics.cornerRadiusMedium)
    }
}
