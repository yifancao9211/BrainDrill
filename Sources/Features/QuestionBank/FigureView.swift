import SwiftUI

/// 把 `FigureSpec` 程序化绘制成图形，用于「图形推理」题型。
struct FigureView: View {
    let spec: FigureSpec
    var size: CGFloat = 52
    var color: Color = BDColor.textPrimary

    var body: some View {
        content
            .frame(width: size, height: size)
            .padding(8)
    }

    @ViewBuilder
    private var content: some View {
        switch spec.shape {
        case .arrow:
            ArrowShape()
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .rotationEffect(.degrees(spec.rotation))
        case .polygon:
            let poly = RegularPolygon(sides: max(3, spec.count))
            if spec.filled {
                poly.fill(color.opacity(0.85)).rotationEffect(.degrees(spec.rotation))
            } else {
                poly.stroke(color, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round)).rotationEffect(.degrees(spec.rotation))
            }
        case .dots:
            dots
        case .lines:
            VStack(spacing: 6) {
                ForEach(0..<max(1, spec.count), id: \.self) { _ in
                    Capsule().fill(color).frame(height: 3)
                }
            }
        case .grid:
            grid
        }
    }

    private var grid: some View {
        let filled = min(max(spec.count, 0), 9)
        return VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { col in
                        let i = row * 3 + col
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(i < filled ? color : color.opacity(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(color.opacity(0.3), lineWidth: 1))
                    }
                }
            }
        }
    }

    private var dots: some View {
        let n = max(1, spec.count)
        let cols = n <= 3 ? n : 3
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(11), spacing: 6), count: cols), spacing: 6) {
            ForEach(0..<n, id: \.self) { _ in
                Circle().fill(color).frame(width: 11, height: 11)
            }
        }
    }
}

/// 指向右侧的箭头（轴 + 箭头），用 `rotationEffect` 表示朝向。
struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midY = rect.midY
        let x0 = rect.minX, w = rect.width, h = rect.height
        // 轴
        p.move(to: CGPoint(x: x0, y: midY))
        p.addLine(to: CGPoint(x: x0 + w * 0.78, y: midY))
        // 箭头
        p.move(to: CGPoint(x: x0 + w * 0.58, y: midY - h * 0.18))
        p.addLine(to: CGPoint(x: x0 + w * 0.80, y: midY))
        p.addLine(to: CGPoint(x: x0 + w * 0.58, y: midY + h * 0.18))
        return p
    }
}

/// 正多边形（顶点向上）。
struct RegularPolygon: Shape {
    let sides: Int

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard sides >= 3 else { return p }
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        for i in 0..<sides {
            let angle = (Double(i) / Double(sides)) * 2 * .pi - .pi / 2
            let pt = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
