import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        BDWorkbenchPage(title: "设置", subtitle: "只保留当前仍在使用的基础训练参数。") {
            SurfaceCard(title: "训练参数", subtitle: "修改后立即保存到本机。") {
                Form {
                    Section("全局") {
                        Toggle("自动升级难度", isOn: Binding(
                            get: { appModel.settings.adaptiveDifficultyEnabled },
                            set: { appModel.updateAdaptiveDifficulty($0) }
                        ))

                        Toggle("显示目标提示", isOn: Binding(
                            get: { appModel.settings.showHints },
                            set: { appModel.updateShowHints($0) }
                        ))

                        Toggle("中心凝视点", isOn: Binding(
                            get: { appModel.settings.showFixationDot },
                            set: { appModel.updateShowFixationDot($0) }
                        ))
                    }

                    Section("舒尔特") {
                        Picker("默认难度", selection: Binding(
                            get: { appModel.settings.preferredDifficulty },
                            set: { appModel.updatePreferredDifficulty($0) }
                        )) {
                            ForEach(SchulteDifficulty.allCases) { difficulty in
                                Text(difficulty.displayName).tag(difficulty)
                            }
                        }

                        LabeledContent("训练结构") {
                            let cfg = appModel.settings.schulteSetRep
                            Text("\(cfg.setsPerSession)组 × \(cfg.repsPerSet)次  间隔 \(cfg.restBetweenRepsSec)s/\(cfg.restBetweenSetsSec)s")
                                .font(.system(.caption, design: .rounded))
                        }
                    }

                    Section("N-Back") {
                        Stepper("起始 N = \(appModel.settings.nBackStartingN)", value: Binding(
                            get: { appModel.settings.nBackStartingN },
                            set: { appModel.settings.nBackStartingN = $0; appModel.persistSettings() }
                        ), in: 1...5)

                        Stepper("刺激时长 = \(appModel.settings.nBackStimulusDurationMs)ms", value: Binding(
                            get: { appModel.settings.nBackStimulusDurationMs },
                            set: { appModel.settings.nBackStimulusDurationMs = $0; appModel.persistSettings() }
                        ), in: 500...1800, step: 100)
                    }

                    Section("视觉搜索") {
                        Stepper("每组试次 = \(appModel.settings.visualSearchTrialsPerSize)", value: Binding(
                            get: { appModel.settings.visualSearchTrialsPerSize },
                            set: { appModel.settings.visualSearchTrialsPerSize = $0; appModel.persistSettings() }
                        ), in: 5...20)
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
                .scrollContentBackground(.hidden)
                .frame(minHeight: 520)
            }
        }
    }
}
