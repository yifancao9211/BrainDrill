import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        SurfaceCard(title: "设置", subtitle: "这些偏好会保存在本机，作为每次训练的默认值。") {
            Form {
                Picker(
                    "默认难度",
                    selection: Binding(
                        get: { appModel.settings.preferredDifficulty },
                        set: { appModel.updatePreferredDifficulty($0) }
                    )
                ) {
                    ForEach(SchulteDifficulty.allCases) { difficulty in
                        Text(difficulty.displayName).tag(difficulty)
                    }
                }

                Toggle(
                    "默认显示当前目标提示",
                    isOn: Binding(
                        get: { appModel.settings.showHints },
                        set: { appModel.updateShowHints($0) }
                    )
                )

                Toggle(
                    "保留音效反馈开关",
                    isOn: Binding(
                        get: { appModel.settings.enableSoundFeedback },
                        set: { appModel.updateSoundFeedback($0) }
                    )
                )

                LabeledContent("数据位置") {
                    Text(appModel.storageLocationDescription)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(2)
                }
            }
            .formStyle(.grouped)
        }
    }
}
