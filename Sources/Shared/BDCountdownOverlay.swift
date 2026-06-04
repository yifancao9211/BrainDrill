import SwiftUI

/// Full-screen countdown overlay that shows a 3-2-1 animation before training starts.
///
/// Place this as an overlay on the training view's root container:
/// ```swift
/// .overlay { BDCountdownOverlay(countdown: countdown) }
/// ```
struct BDCountdownOverlay: View {
    let countdown: CountdownState

    var body: some View {
        if countdown.isActive {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("准备开始")
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .foregroundStyle(BDColor.textSecondary)

                    Text("\(countdown.remaining)")
                        .font(.system(size: 120, weight: .bold, design: .rounded))
                        .foregroundStyle(BDColor.primaryBlue)
                        .contentTransition(.numericText(countsDown: true))
                        .monospacedDigit()
                        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: countdown.remaining)
                        .scaleEffect(scaleForRemaining)
                        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: countdown.remaining)

                    Text("请保持专注")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(BDColor.textSecondary.opacity(0.7))
                }
            }
            .transition(.opacity)
        }
    }

    private var scaleForRemaining: CGFloat {
        switch countdown.remaining {
        case 3: 1.0
        case 2: 1.1
        case 1: 1.2
        default: 1.0
        }
    }
}
