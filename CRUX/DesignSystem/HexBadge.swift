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

/// Grade number inside a hold-colored hexagon with a soft glow.
///
/// `bloom` changing plays a one-time glow bloom — used when a project is sent.
struct HexBadge: View {
    let grade: HexGrade
    let color: HoldColor
    var size: CGFloat = 44
    var glowing = false
    var bloom = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blooming = false

    var body: some View {
        ZStack {
            Hexagon()
                .fill(
                    LinearGradient(
                        colors: [color.color.mix(with: .white, by: 0.12), color.color],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            Hexagon()
                .strokeBorderCompat(Color.white.opacity(color == .black ? 0.22 : 0.18), lineWidth: 1)
            Text("\(grade.rawValue)")
                .font(.system(size: size * 0.44, weight: .bold, design: .rounded))
                .foregroundStyle(color.prefersDarkText ? Color.black.opacity(0.8) : .white)
        }
        .frame(width: size, height: size)
        .shadow(color: color.glow.opacity(glowing ? 0.55 : 0.28), radius: glowing ? size * 0.32 : size * 0.16)
        .overlay {
            Hexagon()
                .stroke(color.glow, lineWidth: 2)
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
}

private extension Shape {
    func strokeBorderCompat(_ color: Color, lineWidth: CGFloat) -> some View {
        stroke(color, lineWidth: lineWidth).padding(lineWidth / 2)
    }
}

#Preview {
    HStack {
        ForEach(HexGrade.allCases) { grade in
            HexBadge(grade: grade, color: HoldColor.allCases[grade.rawValue], glowing: grade == .four)
        }
    }
    .padding()
    .nightGymBackground()
    .preferredColorScheme(.dark)
}
