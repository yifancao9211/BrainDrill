import SwiftUI

/// 考公行测：不选板块/题型，直接开始；全部板块综合出题，偏向较难题目（贴近国考）。
struct CivilExamHubView: View {
    @Environment(AppModel.self) private var appModel
    private let accent = BDColor.teal
    @State private var showBrowse = false

    var body: some View {
        let coord = appModel.civilExamCoord
        Group {
            if coord.isActive {
                QuestionBankSessionView(coordinator: coord, accent: accent) {
                    appModel.finalizeQuestionBankSession(coord)
                }
            } else if let metrics = coord.lastResult?.questionBankMetrics {
                QuestionBankResultView(metrics: metrics, accent: accent, restartTitle: "再来一组") {
                    appModel.dismissQuestionBankResult(coord)
                }
            } else {
                idle(coord: coord)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private func idle(coord: QuestionBankCoordinator) -> some View {
        let total = QuestionBankLibrary.questions(in: coord.availableSections, type: nil, imported: coord.importedQuestions).count
        let sections = coord.availableSections
        return SurfaceCard(
            title: "考公行测",
            subtitle: "判断推理 · 言语理解 · 数量关系 · 资料分析，综合出题、贴近国考难度。",
            accent: accent
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    InfoPill(title: "题库 \(total) 题", accent: BDColor.green)
                    InfoPill(title: "\(sections.count) 大板块", accent: accent)
                    InfoPill(title: "偏难", accent: BDColor.error)
                }

                BDInsightCard(
                    title: "直接开始",
                    bodyText: "无需选择题型，系统从各板块综合抽题、优先较难题目。练习模式逐题给出解析与分步解题；模考模式限时作答。",
                    accent: accent
                )

                if total == 0 {
                    Text("题库为空。请在「素材」中导入考公题库 JSON（section 取 judgment / verbal / quantitative / dataAnalysis）。")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(BDColor.error)
                } else {
                    HStack(spacing: 12) {
                        Button("开始练习（15 题）") {
                            appModel.startCivilExamSession(timed: false, count: 15)
                        }
                        .buttonStyle(BDPrimaryButton(accent: accent))
                        .keyboardShortcut(.defaultAction)

                        Button("限时模考（20 题）") {
                            appModel.startCivilExamSession(timed: true, count: 20)
                        }
                        .buttonStyle(BDSecondaryButton(accent: accent))

                        let dueCount = coord.dueReviewCount(in: coord.availableSections)
                        Button(dueCount > 0 ? "错题复习 (\(dueCount))" : "错题本（暂无）") { appModel.startCivilReview() }
                            .buttonStyle(BDSecondaryButton(accent: BDColor.error))
                            .disabled(dueCount == 0)

                        Button("题库一览") { showBrowse = true }
                            .buttonStyle(BDSecondaryButton(accent: BDColor.textSecondary))
                    }
                }
            }
        }
        .sheet(isPresented: $showBrowse) {
            QuestionBankBrowseView(
                questions: QuestionBankLibrary.questions(in: appModel.civilExamCoord.availableSections, type: nil, imported: appModel.civilExamCoord.importedQuestions),
                accent: accent
            )
        }
    }
}
