import SwiftUI

@main
struct BrainDrillApp: App {
    @State private var appModel = AppModel(store: LocalTrainingStore.live())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
                .environment(appModel)
                .frame(width: 480, height: 360)
        }
    }
}
