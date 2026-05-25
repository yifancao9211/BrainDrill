import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct BrainDrillApp: App {
    @State private var appModel = AppModel(store: LocalTrainingStore.live())

    init() {
        #if os(macOS)
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
        #endif
    }

    var body: some Scene {
        #if os(iOS)
        WindowGroup {
            IOSRootView()
                .environment(appModel)
        }
        #else
        WindowGroup {
            RootView()
                .environment(appModel)
                .frame(minWidth: 1240, minHeight: 820)
        }
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
                .environment(appModel)
                .frame(width: 620, height: 680)
        }
        #endif
    }
}
