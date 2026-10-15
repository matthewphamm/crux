import SwiftUI

/// The grade drawn like Hive's wall tags: a ring of six small hexes where the grade fills
/// that many in (the rest stay as outlines), and 7 hex adds a filled centre.
///
/// Fill order follows Hive's tags: lower-left, bottom, upper-left, top, lower-right, upper-right.
nonisolated struct HexPips: View {
    let count: Int
    var color: Color = .white

    var body: some View {
        Canvas { context, size in
            let badgeRadius = min(size.width, size.height) / 2
            let ringRadius = badgeRadius * Self.ringScale
            let pipRadius = ringRadius * Self.pipToRing
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let filled = min(max(count, 1), 7)
            let lineWidth = max(0.8, pipRadius * 0.2)

            for (index, angle) in Self.fillOrder.enumerated() {
                let radians = angle * .pi / 180
                let point = CGPoint(x: center.x + ringRadius * cos(radians), y: center.y + ringRadius * sin(radians))
                let pip = Self.flatHexagon(center: point, radius: pipRadius)
                if index < filled {
                    context.fill(pip, with: .color(color))
                } else {
                    let inset = Self.flatHexagon(center: point, radius: pipRadius - lineWidth / 2)
                    context.stroke(inset, with: .color(color.opacity(0.55)), lineWidth: lineWidth)
                }
            }

            if filled == 7 {
                context.fill(Self.flatHexagon(center: center, radius: pipRadius), with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Geometry

    /// Ring positions in the order Hive fills them (degrees; 0° is right, 90° is down).
    static let fillOrder: [Double] = [150, 90, 210, 270, 30, 330]

    /// Ring radius relative to the badge radius, and pip size relative to the ring.
    private static let ringScale: CGFloat = 0.5
    private static let pipToRing: CGFloat = 0.42

    /// Flat-topped hexagon, matching the pips on Hive's tags.
    private static func flatHexagon(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for index in 0..<6 {
            let angle = Double(index) * .pi / 3
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
            .frame(width: 56, height: 56)
        }
    }
    .padding()
    .background(Color.black)
}
