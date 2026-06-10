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
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
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
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(minWidth: 48, minHeight: 30)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background((cell.highlight && showContent) ? accent.opacity(0.14) : BDColor.panelFill)
    }
}

// MARK: - 演草纸（可交互排除表）

/// 演草标记：✓（确定是）/ ✗（排除）。
enum ScratchMark: Equatable {
    case yes, no

    /// 点击循环：空白 → ✓ → ✗ → 空白。
    static func next(after mark: ScratchMark?) -> ScratchMark? {
        switch mark {
        case nil:   .yes
        case .yes:  .no
        case .no:   nil
        }
    }
}

/// 演草纸模式：借用题目表格的行列标题，单元格由玩家点击标记 ✓/✗ 自己做排除推理。
/// 只提供空表和标记能力，不泄露任何答案内容。
struct ScratchTableView: View {
    let table: DiagramTable
    var accent: Color = BDColor.syllogismAccent
    @Binding var marks: [String: ScratchMark]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Grid(horizontalSpacing: 1, verticalSpacing: 1) {
                GridRow {
                    headerCell("演草", corner: true)
                    ForEach(Array(table.columns.enumerated()), id: \.offset) { _, col in
                        headerCell(col)
                    }
                }
                ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIndex, row in
                    GridRow {
                        headerCell(row.label, leading: true)
                        ForEach(Array(table.columns.indices), id: \.self) { colIndex in
                            markCell(row: rowIndex, column: colIndex)
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

            HStack {
                Text("点格子标记：✓ 确定 · ✗ 排除 · 再点清除")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(BDColor.textTertiary)
                Spacer()
                if !marks.isEmpty {
                    Button("清空") { marks = [:] }
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .buttonStyle(.plain)
                        .foregroundStyle(accent)
                }
            }
        }
    }

    private func key(_ row: Int, _ column: Int) -> String { "\(row)-\(column)" }

    private func markCell(row: Int, column: Int) -> some View {
        let mark = marks[key(row, column)]
        return Button {
            marks[key(row, column)] = ScratchMark.next(after: mark)
        } label: {
            Group {
                switch mark {
                case .yes:
                    Image(systemName: "checkmark")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(BDColor.green)
                case .no:
                    Image(systemName: "xmark")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(BDColor.error.opacity(0.75))
                case nil:
                    Text(" ")
                }
            }
            .frame(minWidth: 48, minHeight: 30)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .background(mark == nil ? BDColor.panelFill : accent.opacity(0.08))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func headerCell(_ text: String, leading: Bool = false, corner: Bool = false) -> some View {
        Text(text)
            .font(.system(corner ? .caption2 : .caption, design: .rounded, weight: .semibold))
            .foregroundStyle(corner ? BDColor.textTertiary : BDColor.textPrimary)
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minWidth: leading ? 56 : 48, minHeight: 30)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(corner ? BDColor.panelSecondaryFill : accent.opacity(leading ? 0.10 : 0.16))
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
