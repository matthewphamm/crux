import SwiftUI

/// A flat-topped hexagon — CRUX.'s signature shape, echoing Hive's hex tags.
nonisolated struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = side / 2
        let corner = radius * 0.16
        let points = (0..<6).map { index -> CGPoint in
            let angle = Double(index) * .pi / 3
            return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }

        var path = Path()
        for index in 0..<6 {
            let current = points[index]
            let next = points[(index + 1) % 6]
            let previous = points[(index + 5) % 6]
            let start = current.moved(toward: previous, by: corner)
            let end = current.moved(toward: next, by: corner)
            if index == 0 { path.move(to: start) } else { path.addLine(to: start) }
            path.addQuadCurve(to: end, control: current)
        }
        path.closeSubpath()
        return path
    }
}

nonisolated private extension CGPoint {
    func moved(toward other: CGPoint, by distance: CGFloat) -> CGPoint {
        let dx = other.x - x, dy = other.y - y
        let length = max(sqrt(dx * dx + dy * dy), 0.001)
        return CGPoint(x: x + dx / length * distance, y: y + dy / length * distance)
    }
}

/// A grade tag: flat-top hexagon with Hive's pip ring.
///
/// `.glass` (default): dark body, hold-colour rim and pips, faint hold-colour tint.
/// `.fill`: the original solid hold-colour body with white/dark pips.
/// `bloom` changing plays a one-time glow bloom — used when a project is sent.
struct HexBadge: View {
    enum Variant { case glass, fill }

    let grade: HexGrade
    let color: HoldColor
    var size: CGFloat = 44
    var glowing = false
    var bloom = 0
    var dim = false
    var variant: Variant = .glass

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blooming = false

    var body: some View {
        ZStack {
            switch variant {
            case .glass:
                Hexagon()
                    .fill(Color(hex: 0x1C1D21))
                    .padding(size * 0.01)
                Hexagon()
                    .fill(color.color.opacity(0.14))
                    .padding(size * 0.05)
                Hexagon()
                    .stroke(rim, lineWidth: size * 0.04)
                    .padding(size * 0.01)
                HexPips(count: grade.rawValue, color: rim)
            case .fill:
                Hexagon()
                    .fill(
                        LinearGradient(
                            colors: [color.color.mix(with: .white, by: 0.14), color.color],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .padding(size * 0.01)
                Hexagon()
                    .stroke(Color.white.opacity(color == .black ? 0.22 : 0.18), lineWidth: size * 0.02)
                    .padding(size * 0.01)
                HexPips(
                    count: grade.rawValue,
                    color: color.prefersDarkText ? Color.black.opacity(0.78) : Color.white.opacity(0.95)
                )
            }
        }
        .frame(width: size, height: size)
        .shadow(
            color: rim.opacity(glowing ? 0.55 : 0.28),
            radius: (glowing ? size * 0.32 : size * 0.16) * 0.6
        )
        .saturation(dim ? 0 : 1)
        .opacity(dim ? 0.55 : 1)
        .overlay {
            Hexagon()
                .stroke(rim, lineWidth: 2)
                .scaleEffect(blooming ? 1.9 : 1)
                .opacity(blooming ? 0 : (bloom > 0 ? 0.9 : 0))
                .allowsHitTesting(false)
        }
        .animation(Theme.spring, value: glowing)
        .onChange(of: bloom) {
            guard !reduceMotion else { return }
            blooming = false
            withAnimation(.easeOut(duration: 0.9)) { blooming = true }
        }
        .accessibilityElement()
        .accessibilityLabel("\(grade.label), \(color.name)")
    }

    /// Rim, pips and glow. Black holds use a cool grey so they stay visible.
    private var rim: Color { color.glow }
}

private extension Shape {
    func strokeBorderCompat(_ color: Color, lineWidth: CGFloat) -> some View {
        stroke(color, lineWidth: lineWidth).padding(lineWidth / 2)
    }
}

#Preview {
    HStack {
        ForEach(HexGrade.allCases) { grade in
            HexBadge(grade: grade, color: HoldColor.allCases[grade.rawValue], size: 56, glowing: grade == .four)
        }
    }
    .padding()
    .nightGymBackground()
    .preferredColorScheme(.dark)
}
