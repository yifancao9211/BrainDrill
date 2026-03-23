import SwiftUI

@main
struct BrainDrillApp: App {
    @State private var appModel = AppModel(store: LocalTrainingStore.live())

    var body: some Scene {
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
    }
}
