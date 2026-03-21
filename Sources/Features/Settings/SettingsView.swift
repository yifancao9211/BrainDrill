import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        SurfaceCard(title: "设置", subtitle: "训练参数会保存在本机。") {
            Form {
                Section("舒尔特方格") {
                    Picker("默认难度", selection: Binding(
                        get: { appModel.settings.preferredDifficulty },
                        set: { appModel.updatePreferredDifficulty($0) }
                    )) {
                        ForEach(SchulteDifficulty.allCases) { d in
                            Text(d.displayName).tag(d)
                        }
                    }

                    Toggle("显示目标提示", isOn: Binding(
                        get: { appModel.settings.showHints },
                        set: { appModel.updateShowHints($0) }
                    ))

                    Toggle("中心凝视点", isOn: Binding(
                        get: { appModel.settings.showFixationDot },
                        set: { appModel.updateShowFixationDot($0) }
                    ))

                    Toggle("自动升级难度", isOn: Binding(
                        get: { appModel.settings.adaptiveDifficultyEnabled },
                        set: { appModel.updateAdaptiveDifficulty($0) }
                    ))

                    LabeledContent("训练结构") {
                        let c = appModel.settings.schulteSetRep
                        Text("\(c.setsPerSession)组 × \(c.repsPerSet)次  间隔 \(c.restBetweenRepsSec)s/\(c.restBetweenSetsSec)s")
                            .font(.system(.caption, design: .rounded))
                    }
                }

                Section("Flanker 反应力") {
                    LabeledContent("刺激时长") {
                        Text("\(appModel.settings.flankerStimulusDurationMs)ms")
                            .font(.system(.caption, design: .rounded))
                    }
                }

                Section("N-Back 记忆") {
                    Stepper("起始 N = \(appModel.settings.nBackStartingN)", value: Binding(
                        get: { appModel.settings.nBackStartingN },
                        set: { appModel.settings.nBackStartingN = $0; appModel.persistSettings() }
                    ), in: 1...5)
                }

                Section("数字广度") {
                    Stepper("起始长度 = \(appModel.settings.digitSpanStartingLength)", value: Binding(
                        get: { appModel.settings.digitSpanStartingLength },
                        set: { appModel.settings.digitSpanStartingLength = $0; appModel.persistSettings() }
                    ), in: 2...8)

                    Stepper("呈现速度 = \(appModel.settings.digitSpanPresentationMs)ms", value: Binding(
                        get: { appModel.settings.digitSpanPresentationMs },
                        set: { appModel.settings.digitSpanPresentationMs = $0; appModel.persistSettings() }
                    ), in: 500...2000, step: 100)
                }

                Section("选择反应时") {
                    Picker("选项数", selection: Binding(
                        get: { appModel.settings.choiceRTChoiceCount },
                        set: { appModel.settings.choiceRTChoiceCount = $0; appModel.persistSettings() }
                    )) {
                        Text("2").tag(2)
                        Text("3").tag(3)
                        Text("4").tag(4)
                    }
                    .pickerStyle(.segmented)

                    Stepper("每组试次 = \(appModel.settings.choiceRTTrialsPerBlock)", value: Binding(
                        get: { appModel.settings.choiceRTTrialsPerBlock },
                        set: { appModel.settings.choiceRTTrialsPerBlock = $0; appModel.persistSettings() }
                    ), in: 10...60, step: 5)
                }

                Section("变更检测") {
                    Stepper("初始集合大小 = \(appModel.settings.changeDetectionInitialSetSize)", value: Binding(
                        get: { appModel.settings.changeDetectionInitialSetSize },
                        set: { appModel.settings.changeDetectionInitialSetSize = $0; appModel.persistSettings() }
                    ), in: 2...6)

                    Stepper("编码时长 = \(appModel.settings.changeDetectionEncodingMs)ms", value: Binding(
                        get: { appModel.settings.changeDetectionEncodingMs },
                        set: { appModel.settings.changeDetectionEncodingMs = $0; appModel.persistSettings() }
                    ), in: 200...1500, step: 100)

                    Stepper("保持时长 = \(appModel.settings.changeDetectionRetentionMs)ms", value: Binding(
                        get: { appModel.settings.changeDetectionRetentionMs },
                        set: { appModel.settings.changeDetectionRetentionMs = $0; appModel.persistSettings() }
                    ), in: 300...2000, step: 100)
                }

                Section("视觉搜索") {
                    Stepper("每组试次 = \(appModel.settings.visualSearchTrialsPerSize)", value: Binding(
                        get: { appModel.settings.visualSearchTrialsPerSize },
                        set: { appModel.settings.visualSearchTrialsPerSize = $0; appModel.persistSettings() }
                    ), in: 5...20)
                }

                Section("AI 教练") {
                    TextField("API 地址", text: Binding(
                        get: { appModel.settings.aiBaseURL },
                        set: { appModel.updateAIConfig(baseURL: $0, apiKey: appModel.settings.aiAPIKey) }
                    ))
                    .font(.system(.caption, design: .monospaced))

                    SecureField("API Key", text: Binding(
                        get: { appModel.settings.aiAPIKey },
                        set: { appModel.updateAIConfig(baseURL: appModel.settings.aiBaseURL, apiKey: $0) }
                    ))
                    .font(.system(.caption, design: .monospaced))
                }

                Section("数据") {
                    LabeledContent("存储位置") {
                        Text(appModel.storageLocationDescription)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(2)
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}
