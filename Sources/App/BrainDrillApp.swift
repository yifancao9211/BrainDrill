import SwiftUI

@main
struct BrainDrillApp: App {
    @State private var appModel = AppModel(store: LocalTrainingStore.live())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .frame(minWidth: 1060, minHeight: 720)
        }
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
                .environment(appModel)
                .frame(width: 520, height: 480)
        }
    }
}
