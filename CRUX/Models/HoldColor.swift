import SwiftUI

/// The hold or tape color of a problem — how you actually find it on the wall.
nonisolated enum HoldColor: String, CaseIterable, Identifiable, Codable {
    case red, orange, yellow, green, teal, blue, purple, pink, black, white

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    /// Base swatch, tuned to sit calmly on the dark Night Gym background.
    var color: Color {
        switch self {
        case .red: Color(hex: 0xE5534B)
        case .orange: Color(hex: 0xEE8A3C)
        case .yellow: Color(hex: 0xF2D04B)
        case .green: Color(hex: 0x4CB782)
        case .teal: Color(hex: 0x3BB8B0)
        case .blue: Color(hex: 0x4A8FE7)
        case .purple: Color(hex: 0x9B6FE0)
        case .pink: Color(hex: 0xE77BB5)
        case .black: Color(hex: 0x34353A)
        case .white: Color(hex: 0xEDEDEA)
        }
    }

    /// The soft halo drawn around badges. Black holds glow a cool grey so they stay visible.
    var glow: Color {
        switch self {
        case .black: Color(hex: 0x8A8B92)
        default: color
        }
    }

    /// Light swatches need dark text for contrast.
    var prefersDarkText: Bool { self == .yellow || self == .white }
}
