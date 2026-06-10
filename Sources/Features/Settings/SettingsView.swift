import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        BDWorkbenchPage(
            title: "设置",
            subtitle: "训练参数和本地数据都在这里统一管理。",
            maxContentWidth: BDMetrics.contentMaxWorkbenchWidth
        ) {
            SurfaceCard(title: "全局训练", subtitle: "这些开关会直接影响大多数训练模块。", accent: BDColor.primaryBlue) {
                VStack(spacing: 10) {
                    settingToggle(
                        title: "自动升级难度",
                        subtitle: "根据最近表现调整推荐起始难度。",
                        isOn: Binding(
                            get: { appModel.settings.adaptiveDifficultyEnabled },
                            set: { appModel.updateAdaptiveDifficulty($0) }
                        )
                    )
                    settingToggle(
                        title: "中心凝视点",
                        subtitle: "在需要稳定视线的模块中显示中心参考点。",
                        isOn: Binding(
                            get: { appModel.settings.showFixationDot },
                            set: { appModel.updateShowFixationDot($0) }
                        )
                    )
                }
            }

            BDAdaptiveColumns(secondaryWidth: 360) {
                SurfaceCard(title: "舒尔特与视觉搜索", subtitle: "管理经典视觉注意训练的默认参数。", accent: BDColor.primaryBlue) {
                    VStack(spacing: 10) {
                        BDSettingsRow(title: "默认难度", subtitle: "舒尔特训练启动时使用的默认等级。") {
                            Picker("默认难度", selection: Binding(
                                get: { appModel.settings.preferredDifficulty },
                                set: { appModel.updatePreferredDifficulty($0) }
                            )) {
                                ForEach(SchulteDifficulty.allCases) { difficulty in
                                    Text(difficulty.displayName).tag(difficulty)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        settingToggle(
                            title: "硬核模式",
                            subtitle: "已找到的数字不变灰不划线，全程保持满负荷视觉搜索。",
                            isOn: Binding(
                                get: { appModel.settings.schulteHardcoreMode },
                                set: { appModel.updateSchulteHardcoreMode($0) }
                            )
                        )

                        BDSettingsRow(title: "舒尔特结构", subtitle: "默认短训组次与休息时间。", controlAlignment: .leading) {
                            let cfg = appModel.settings.schulteSetRep
                            Text("\(cfg.setsPerSession) 组 × \(cfg.repsPerSet) 次，组内休息 \(cfg.restBetweenRepsSec)s，组间休息 \(cfg.restBetweenSetsSec)s")
                                .font(.system(.footnote))
                                .foregroundStyle(BDColor.textSecondary)
                                .frame(maxWidth: 280, alignment: .leading)
                        }
                    }
                }
            } secondary: {
                SurfaceCard(title: "工作记忆", subtitle: "N-Back 的默认起始负荷与呈现节奏。", accent: BDColor.nBackAccent) {
                    VStack(spacing: 10) {
                        stepperRow(
                            title: "起始 N",
                            subtitle: "训练开始时使用的默认 N 值。",
                            value: Binding(
                                get: { appModel.settings.nBackStartingN },
                                set: { appModel.settings.nBackStartingN = $0; appModel.persistSettings() }
                            ),
                            range: 1...5
                        )

                        stepperRow(
                            title: "参考节奏",
                            subtitle: "用于自适应评分的参考时长；训练中由用户推进。",
                            value: Binding(
                                get: { appModel.settings.nBackStimulusDurationMs },
                                set: { appModel.settings.nBackStimulusDurationMs = $0; appModel.persistSettings() }
                            ),
                            range: 500...1800,
                            step: 100,
                            formatter: { "\($0) ms" }
                        )
                    }
                }
            }

            SurfaceCard(title: "本地数据", subtitle: "应用当前的本地存储位置。", accent: BDColor.teal) {
                BDSettingsRow(title: "存储路径", subtitle: "当前设备上的应用数据目录。", controlAlignment: .leading) {
                    Text(appModel.storageLocationDescription)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(BDColor.textSecondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: 320, alignment: .leading)
                }
            }
        }
    }

    private func settingToggle(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        BDSettingsRow(title: title, subtitle: subtitle, controlAlignment: .center) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .bdFocusRing(cornerRadius: 10)
        }
    }

    private func settingField<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        BDSettingsRow(title: title, subtitle: subtitle, controlAlignment: .leading, control: content)
    }

    private func stepperRow(
        title: String,
        subtitle: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int = 1,
        formatter: @escaping (Int) -> String = { "\($0)" }
    ) -> some View {
        BDSettingsRow(title: title, subtitle: subtitle, controlAlignment: .leading) {
            HStack(spacing: 12) {
                Text(formatter(value.wrappedValue))
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(BDColor.textPrimary)
                    .frame(width: 72, alignment: .leading)
                Stepper("", value: value, in: range, step: step)
                    .labelsHidden()
                    .bdFocusRing(cornerRadius: 10)
            }
        }
    }
}
