import Foundation
import SwiftData

@Model
final class Climb {
    var id: UUID = UUID()
    var gradeValue: Int = 1
    var holdColorRaw: String = HoldColor.blue.rawValue
    var name: String = ""
    var notes: String = ""
    var styleTagsRaw: [String] = []
    var createdAt: Date = Date.now
    /// Set when the wall is reset; the climb moves to the Stripped archive but keeps its history.
    var strippedAt: Date?
    var isOnTickList: Bool = false
    var isProjectFlagged: Bool = false
    var wall: Wall?

    @Relationship(deleteRule: .cascade, inverse: \Attempt.climb)
    var attempts: [Attempt]? = []

    @Relationship(deleteRule: .cascade, inverse: \BetaMedia.climb)
    var media: [BetaMedia]? = []

    init(
        grade: HexGrade,
        holdColor: HoldColor,
        name: String = "",
        styleTags: Set<StyleTag> = [],
        createdAt: Date = .now
    ) {
        self.gradeValue = grade.rawValue
        self.holdColorRaw = holdColor.rawValue
        self.name = name
        self.styleTagsRaw = styleTags.map(\.rawValue).sorted()
        self.createdAt = createdAt
    }

    var grade: HexGrade {
        get { HexGrade(clamping: gradeValue) }
        set { gradeValue = newValue.rawValue }
    }

    var holdColor: HoldColor {
        get { HoldColor(rawValue: holdColorRaw) ?? .blue }
        set { holdColorRaw = newValue.rawValue }
    }

    var styleTags: Set<StyleTag> {
        get { Set(styleTagsRaw.compactMap(StyleTag.init(rawValue:))) }
        set { styleTagsRaw = newValue.map(\.rawValue).sorted() }
    }

    var isActive: Bool { strippedAt == nil }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "\(holdColor.name) \(grade.label)" : trimmed
    }
}
