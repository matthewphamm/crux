import Foundation

/// A bouldering grading scale. CRUX. ships with Hive's Hex scale; other gyms can add their own conformer
/// later without migrating stored data, since climbs store a plain integer grade.
nonisolated protocol GradeSystem {
    var id: String { get }
    var name: String { get }
    var grades: ClosedRange<Int> { get }
    func label(for grade: Int) -> String
    func approximateV(for grade: Int) -> String?
}

/// Hive Climbing's 1–7 Hex scale (https://hiveclimbing.com/climb-overview).
nonisolated struct HiveHex: GradeSystem {
    static let shared = HiveHex()

    let id = "hive-hex"
    let name = "Hive Hex"
    let grades = 1...7

    func label(for grade: Int) -> String { "\(grade) Hex" }
    func approximateV(for grade: Int) -> String? { HexGrade(rawValue: grade)?.vRange }
}

/// A single Hex grade. Stored on climbs as its raw `Int` value.
nonisolated enum HexGrade: Int, CaseIterable, Identifiable, Comparable, Codable {
    case one = 1, two, three, four, five, six, seven

    var id: Int { rawValue }

    /// Hive's published approximate V-grade range. Grading is subjective; adjacent grades overlap.
    var vRange: String {
        switch self {
        case .one: "VB–V0"
        case .two: "V0–V2"
        case .three: "V2–V4"
        case .four: "V4–V6"
        case .five: "V6–V8"
        case .six: "V8–V10"
        case .seven: "V10+"
        }
    }

    var label: String { "\(rawValue) Hex" }
    var fullLabel: String { "\(label) · \(vRange)" }

    static func < (lhs: HexGrade, rhs: HexGrade) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Clamps any stored integer into the valid range.
    init(clamping value: Int) {
        self = HexGrade(rawValue: min(max(value, 1), 7)) ?? .one
    }
}
