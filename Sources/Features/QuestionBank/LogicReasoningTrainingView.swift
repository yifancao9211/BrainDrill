import SwiftUI

/// 逻辑推理练习题模块视图：演绎谜题（读场景与线索，推出唯一解）。
/// 复用共享的题库练习框架（`QuestionBankCoordinator` + `QuestionBankSessionView`）。
struct LogicReasoningTrainingView: View {
    @Environment(AppModel.self) private var appModel

    private let accent = BDColor.syllogismAccent
    @State private var showBrowse = false

    var body: some View {
        let coord = appModel.logicReasoningCoord
        Group {
            if coord.isActive {
                QuestionBankSessionView(coordinator: coord, accent: accent) {
                    appModel.finalizeQuestionBankSession(coord)
                }
            } else if let metrics = coord.lastResult?.questionBankMetrics {
                QuestionBankResultView(
                    metrics: metrics,
                    accent: accent,
                    restartTitle: "再来一组"
                ) {
                    appModel.startLogicReasoningSession()
                }
            } else {
                idlePanel(coord: coord)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private func idlePanel(coord: QuestionBankCoordinator) -> some View {
        let total = QuestionBankLibrary.questions(in: [.logicReasoning], type: nil, imported: coord.importedQuestions).count
        let weak = coord.weakTypes(in: [.logicReasoning])
        let level = appModel.adaptiveState(for: .logicReasoning).recommendedStartLevel

        return SurfaceCard(
            title: "逻辑推理",
            subtitle: "读懂场景与线索，推出唯一确定的答案。",
            accent: accent
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    InfoPill(title: "推荐 Level \(level)", accent: accent)
                    InfoPill(title: "题库 \(total) 题", accent: BDColor.green)
                    if !weak.isEmpty {
                        InfoPill(title: "\(weak.count) 个薄弱题型", accent: BDColor.error)
                    }
                }

                BDInsightCard(
                    title: "训练说明",
                    bodyText: "每组 10 题，覆盖对应推理、排序推理、真假推理、位置推理等演绎题型。逐题作答后立即给出解析，薄弱题型会优先出现。",
                    accent: accent
                )

                if total == 0 {
                    Text("题库为空，请在「素材」中导入逻辑推理题库 JSON。")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(BDColor.error)
                }

                let dueCount = coord.dueReviewCount(in: [.logicReasoning])
                HStack(spacing: 12) {
                    Button("开始练习") {
                        appModel.startLogicReasoningSession()
                    }
                    .buttonStyle(BDPrimaryButton(accent: accent))
                    .keyboardShortcut(.defaultAction)
                    .disabled(total == 0)

                    Button(dueCount > 0 ? "错题复习 (\(dueCount))" : "错题本（暂无）") { appModel.startLogicReview() }
                        .buttonStyle(BDSecondaryButton(accent: BDColor.error))
                        .disabled(dueCount == 0)

                    Button("题库一览") { showBrowse = true }
                        .buttonStyle(BDSecondaryButton(accent: BDColor.textSecondary))
                        .disabled(total == 0)
                }
            }
        }
        .sheet(isPresented: $showBrowse) {
            QuestionBankBrowseView(
                questions: QuestionBankLibrary.questions(in: [.logicReasoning], type: nil, imported: coord.importedQuestions),
                accent: accent
            )
        }
    }
}
