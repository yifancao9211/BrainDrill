import SwiftUI

/// 渲染解题图示（表格排除法 / 假设法表格 / 结果对应表）。
/// `scaffold = true` 时只显示行列标题、清空单元格，用作答题前的「解题脚手架」提示。
struct DiagramTableView: View {
    let table: DiagramTable
    var accent: Color = BDColor.syllogismAccent
    var scaffold: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = table.title, !title.isEmpty {
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(accent)
            }

            Grid(horizontalSpacing: 1, verticalSpacing: 1) {
                // 表头行
                GridRow {
                    cornerCell
                    ForEach(Array(table.columns.enumerated()), id: \.offset) { _, col in
                        headerCell(col)
                    }
                }
                // 数据行
                ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        headerCell(row.label, leading: true)
                        ForEach(Array(row.cells.enumerated()), id: \.offset) { idx, cell in
                            dataCell(idx < row.cells.count ? cell : DiagramCell(kind: .blank))
                        }
                    }
                }
            }
            .background(Color.bdSeparator.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.bdSeparator.opacity(0.4), lineWidth: 0.5)
            )

            if !scaffold, let caption = table.caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(BDColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var cornerCell: some View {
        Text(scaffold ? "填表" : "")
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .foregroundStyle(BDColor.textTertiary)
            .frame(minWidth: 52, minHeight: 30)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .background(BDColor.panelSecondaryFill)
    }

    private func headerCell(_ text: String, leading: Bool = false) -> some View {
        Text(text)
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(BDColor.textPrimary)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.center)
            .frame(minWidth: leading ? 56 : 48, minHeight: 30)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(accent.opacity(leading ? 0.10 : 0.16))
    }

    @ViewBuilder
    private func dataCell(_ cell: DiagramCell) -> some View {
        let showContent = !scaffold
        Group {
            switch cell.kind {
            case .yes:
                Image(systemName: "checkmark")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(showContent ? BDColor.green : .clear)
            case .no:
                Image(systemName: "xmark")
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(showContent ? BDColor.textTertiary : .clear)
            case .blank:
                Text(" ")
            case .value:
                Text(showContent ? cell.text : " ")
                    .font(.system(.caption, design: .rounded, weight: cell.highlight ? .bold : .regular))
                    .foregroundStyle(cell.highlight && showContent ? accent : BDColor.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(minWidth: 48, minHeight: 30)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background((cell.highlight && showContent) ? accent.opacity(0.14) : BDColor.panelFill)
    }
}

/// 分步推理列表：编号步骤 + 每步的推导文字 + 该步的表格快照（若有）。
/// `revealedCount` 控制显示前几步，用于「逐步揭示」的提示流。
struct SolutionStepsView: View {
    let steps: [SolutionStep]
    var accent: Color = BDColor.syllogismAccent
    var revealedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(steps.prefix(max(0, revealedCount)).enumerated()), id: \.offset) { index, step in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(accent))
                        Text(step.text)
                            .font(.system(.callout, design: .rounded))
                            .foregroundStyle(BDColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let diagram = step.diagram {
                        DiagramTableView(table: diagram, accent: accent, scaffold: false)
                            .padding(.leading, 32)
                    }
                }
            }
        }
    }
}
