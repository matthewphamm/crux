import Foundation

/// Movement and terrain tags, used to spot strengths and weaknesses in Stats.
nonisolated enum StyleTag: String, CaseIterable, Identifiable, Codable {
    case slab, vertical, overhang, roof
    case crimpy, slopey, pinchy, jugs
    case dyno, coordination, compression, mantle, technical

    var id: String { rawValue }
    var name: String { rawValue.capitalized }
}
