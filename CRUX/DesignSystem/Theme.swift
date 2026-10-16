import SwiftUI

/// Night Gym design tokens ("Night Gym, evolved"). Dark only.
enum Theme {
    static let background = Color(hex: 0x121315)
    static let ink = Color(hex: 0xEDEDEA)
    static let inkSecondary = Color(hex: 0x8E8F95)
    static let inkTertiary = Color(hex: 0x5C5D63)
    static let hairline = Color.white.opacity(0.08)

    /// The only accent: Start, tab selection, links, projects.
    static let accent = Color(hex: 0xF2B45A)
    /// Text and icons on amber.
    static let onAccent = Color(hex: 0x241806)
    static let send = Color(hex: 0x5CC98C)
    static let onSend = Color(hex: 0x0E2A1B)
    /// Reset, stripped, delete.
    static let danger = Color(hex: 0xE5675F)
    static let stripped = danger

    /// `glassCard` fill and border.
    static let cardFill = Color.white.opacity(0.055)
    static let cardBorder = Color.white.opacity(0.08)
    /// Round toolbar buttons, the gym pill, secondary buttons.
    static let controlFill = Color.white.opacity(0.07)
    static let controlBorder = Color.white.opacity(0.09)
    static let segmentTrack = Color.white.opacity(0.06)
    static let segmentSelected = Color.white.opacity(0.14)
    /// Topped climbs in a session.
    static let sentFill = Color(hex: 0x5CC98C, opacity: 0.08)
    static let sentBorder = Color(hex: 0x5CC98C, opacity: 0.22)
    static let sheet = Color(hex: 0x1A1B1E)
    /// Empty hex cells (week strip, ladder).
    static let emptyCell = Color(hex: 0x25262A)
    /// Unselected tab items.
    static let tabIdle = Color(hex: 0xC9CAC6)

    /// Kept for older call sites; equals `cardFill` on the dark ground.
    static let surfaceRaised = Color.white.opacity(0.07)

    enum Radius {
        static let card: CGFloat = 26
        static let row: CGFloat = 22
        static let chip: CGFloat = 18
        static let sheet: CGFloat = 34
    }

    enum Spacing {
        static let gutter: CGFloat = 16
        static let stack: CGFloat = 12
        static let section: CGFloat = 26
        static let cardGap: CGFloat = 10
    }

    /// State changes across the app — quick, no bounce theatrics.
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.86)
    /// Full-screen covers and big moves: cubic-bezier(.2, .8, .2, 1), 0.4s.
    static let slide = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.4)
}

extension Font {
    /// SF Pro Rounded for every number: timers, counts, stats, grade numerals. Tabular digits.
    static func number(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .rounded, weight: weight).monospacedDigit()
    }

    static func number(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    /// 34 / 700 large title.
    static let largeTitleCrux = Font.system(size: 34, weight: .bold)
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

    /// Dark-only app: the dark value is always used. Kept so older call sites compile.
    init(light: UInt32, dark: UInt32) {
        self.init(hex: dark)
    }
}

/// Chart tokens, validated for colorblind separation against the dark surface.
extension Theme {
    enum Chart {
        static let flash = Color(hex: 0xB98035)
        static let send = Color(hex: 0x5B8DEF)
    }
}

extension HexGrade {
    /// Grades are ordered magnitude, so charts use one hue stepping from quiet (easy) to strong (hard).
    var tint: Color {
        let ramp: [UInt32] = [0x2B3E63, 0x34518A, 0x3E64AF, 0x4C78D0, 0x6A92E6, 0x8FAEF0, 0xB9CDF7]
        return Color(hex: ramp[rawValue - 1])
    }
}

/// The app backdrop: near-black with an amber glow top-left and a blue glow bottom-right.
struct NightGymBackground: View {
    var tint: Color? = nil

    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(
                stops: [.init(color: Theme.accent.opacity(0.14), location: 0), .init(color: .clear, location: 0.7)],
                center: .topLeading, startRadius: 0, endRadius: 520
            )
            RadialGradient(
                colors: [Color(hex: 0x4A8FE7, opacity: 0.10), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 560
            )
            if let tint {
                RadialGradient(
                    colors: [tint.opacity(0.2), .clear],
                    center: UnitPoint(x: 0.5, y: 0.12), startRadius: 0, endRadius: 380
                )
            }
        }
        .ignoresSafeArea()
    }
}

extension View {
    func nightGymBackground(tint: Color? = nil) -> some View {
        background { NightGymBackground(tint: tint) }
            .scrollContentBackground(.hidden)
    }
}
