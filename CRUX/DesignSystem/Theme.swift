import SwiftUI

/// Night Gym design tokens. Dark-first; every token has a light-mode counterpart.
enum Theme {
    static let background = Color(light: 0xF3F2EF, dark: 0x121315)
    static let surface = Color(light: 0xFFFFFF, dark: 0x1A1B1E)
    static let surfaceRaised = Color(light: 0xEAE9E5, dark: 0x232428)
    static let ink = Color(light: 0x18191B, dark: 0xEDEDEA)
    static let inkSecondary = Color(light: 0x66676B, dark: 0x8E8F95)
    static let inkTertiary = Color(light: 0x9A9B9F, dark: 0x5C5D63)
    static let hairline = Color(light: 0x000000, dark: 0xFFFFFF).opacity(0.08)

    /// A soft amber, like chalk under warm gym lights. The only accent.
    static let accent = Color(light: 0xB8761F, dark: 0xF2B45A)
    static let send = Color(light: 0x2F8F5B, dark: 0x5CC98C)
    /// Soft red for climbs that are no longer on the wall.
    static let stripped = Color(light: 0xC2413A, dark: 0xE5675F)

    enum Radius {
        static let card: CGFloat = 26
        static let control: CGFloat = 16
    }

    enum Spacing {
        static let gutter: CGFloat = 16
        static let stack: CGFloat = 12
        static let section: CGFloat = 28
    }

    /// Spring used for state changes across the app — quick, no bounce theatrics.
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.86)
}

extension Font {
    /// Rounded numerals for counts, grades and timers.
    static func number(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .rounded, weight: weight).monospacedDigit()
    }
}

nonisolated extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

/// Chart tokens, validated for colorblind separation against both surfaces.
extension Theme {
    enum Chart {
        static let flash = Color(light: 0xB8761F, dark: 0xB98035)
        static let send = Color(light: 0x3D6FD1, dark: 0x5B8DEF)
    }
}

extension HexGrade {
    /// Grades are ordered magnitude, so charts use one hue stepping from quiet (easy) to strong (hard).
    var tint: Color {
        let dark: [UInt32] = [0x2B3E63, 0x34518A, 0x3E64AF, 0x4C78D0, 0x6A92E6, 0x8FAEF0, 0xB9CDF7]
        let light: [UInt32] = [0xC9D8F5, 0xA7C0EE, 0x82A4E3, 0x5F88D6, 0x416EC4, 0x2F56A3, 0x203D7A]
        return Color(light: light[rawValue - 1], dark: dark[rawValue - 1])
    }
}

/// The app backdrop: near-black with two faint glows, so glass has something to refract.
struct NightGymBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(
                colors: [Theme.accent.opacity(scheme == .dark ? 0.14 : 0.10), .clear],
                center: .topLeading, startRadius: 20, endRadius: 520
            )
            RadialGradient(
                colors: [Color(hex: 0x4A8FE7).opacity(scheme == .dark ? 0.10 : 0.06), .clear],
                center: .bottomTrailing, startRadius: 20, endRadius: 560
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    func nightGymBackground() -> some View {
        background { NightGymBackground() }
            .scrollContentBackground(.hidden)
    }
}
