import SwiftUI

struct AIChatPanel: View {
    @Binding var isOpen: Bool

    var body: some View {
        if isOpen {
            HStack(spacing: 0) {
                Divider()
                AIChatView()
                    .frame(width: 350)
                    .background(.ultraThinMaterial)
                    .transition(.move(edge: .trailing))
            }
        }
    }
}
