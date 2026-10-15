import SwiftUI

/// The grade drawn the way Hive tags it on the wall: a little honeycomb of 1–7 hexes.
///
/// 1 single · 2 pair · 3 triangle · 4 diamond · 5 pyramid · 6 ring · 7 flower.
nonisolated struct HexPips: View {
    let count: Int
    var color: Color = .white

    var body: some View {
        Canvas { context, size in
            let layout = Self.layout(for: count)
            let radius = min(size.width, size.height) / 2
            // Fit the cluster inside the badge's inner circle, but don't let a lone hex get huge.
            let scale = min(radius * 0.66 / layout.extent, radius * 0.34 / Self.pipRadius)
            let pip = Self.pipRadius * scale
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            for point in layout.points {
                let c = CGPoint(x: center.x + point.x * scale, y: center.y + point.y * scale)
                context.fill(Self.pointyHexagon(center: c, radius: pip), with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Geometry (unit neighbour distance = 1)

    /// Small hexes are slightly smaller than the grid so they read as separate tiles.
    private static let pipRadius: CGFloat = 0.44

    private static let h = CGFloat(3).squareRoot() / 2 // row height for neighbour distance 1

    static func layout(for count: Int) -> (points: [CGPoint], extent: CGFloat) {
        let points: [CGPoint]
        switch min(max(count, 1), 7) {
        case 1:
            points = [.zero]
        case 2:
            points = [CGPoint(x: -0.5, y: 0), CGPoint(x: 0.5, y: 0)]
        case 3:
            points = [CGPoint(x: 0, y: -h * 2 / 3), CGPoint(x: -0.5, y: h / 3), CGPoint(x: 0.5, y: h / 3)]
        case 4:
            points = [CGPoint(x: 0, y: -h), CGPoint(x: -0.5, y: 0), CGPoint(x: 0.5, y: 0), CGPoint(x: 0, y: h)]
        case 5:
            points = [
                CGPoint(x: -0.5, y: -h / 2), CGPoint(x: 0.5, y: -h / 2),
                CGPoint(x: -1, y: h / 2), CGPoint(x: 0, y: h / 2), CGPoint(x: 1, y: h / 2),
            ]
        case 6:
            points = ring
        default:
            points = [.zero] + ring
        }
        let extent = (points.map { ($0.x * $0.x + $0.y * $0.y).squareRoot() }.max() ?? 0) + pipRadius
        return (points, extent)
    }

    private static var ring: [CGPoint] {
        (0..<6).map { index in
            let angle = Double(index) * .pi / 3
            return CGPoint(x: cos(angle), y: sin(angle))
        }
    }

    /// Pointy-top hexagon so neighbours sit side by side in rows.
    private static func pointyHexagon(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for index in 0..<6 {
            let angle = Double(index) * .pi / 3 - .pi / 2
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    HStack(spacing: 10) {
        ForEach(1...7, id: \.self) { count in
            ZStack {
                Hexagon().fill(Color(hex: 0x4A8FE7))
                HexPips(count: count)
            }
            .frame(width: 48, height: 48)
        }
    }
    .padding()
    .background(Color.black)
}
