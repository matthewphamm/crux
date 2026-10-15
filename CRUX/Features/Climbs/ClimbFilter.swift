import Foundation

enum ClimbSegment: String, CaseIterable, Identifiable {
    case projects = "Projects"
    case all = "All"
    case stripped = "Stripped"

    var id: String { rawValue }
}

enum ClimbSort: String, CaseIterable, Identifiable {
    case grade = "Grade"
    case recent = "Recent"
    case attempts = "Tries"

    var id: String { rawValue }
}

/// Everything the Climbs tab can narrow by. Pure value type so it's trivially testable.
/// Every set is "match any"; an empty set means no filter on that field.
struct ClimbFilter: Equatable {
    var grades: Set<HexGrade> = []
    var wallIDs: Set<UUID> = []
    var colors: Set<HoldColor> = []
    var statuses: Set<ClimbStatus> = []
    var tags: Set<StyleTag> = []

    var isActive: Bool { self != ClimbFilter() }

    /// How many of the options in the Filter sheet are in use (grade has its own strip).
    var sheetFilterCount: Int {
        wallIDs.count + colors.count + statuses.count + tags.count
    }

    func matches(_ climb: Climb) -> Bool {
        (grades.isEmpty || grades.contains(climb.grade))
            && (wallIDs.isEmpty || climb.wall.map { wallIDs.contains($0.id) } == true)
            && (colors.isEmpty || colors.contains(climb.holdColor))
            && (statuses.isEmpty || statuses.contains(climb.status))
            && (tags.isEmpty || !tags.isDisjoint(with: climb.styleTags))
    }

    static func apply(
        _ climbs: [Climb], segment: ClimbSegment, filter: ClimbFilter, sort: ClimbSort, query: String = ""
    ) -> [Climb] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        let inSegment = climbs.filter { climb in
            switch segment {
            case .projects: climb.isActive && climb.status == .project
            case .all: climb.isActive
            case .stripped: !climb.isActive
            }
        }
        let filtered = inSegment.filter { filter.matches($0) && (q.isEmpty || $0.displayName.lowercased().contains(q)) }

        switch sort {
        case .grade:
            return filtered.sorted { ($0.gradeValue, $0.createdAt) > ($1.gradeValue, $1.createdAt) }
        case .recent:
            return filtered.sorted { lastTouched($0) > lastTouched($1) }
        case .attempts:
            return filtered.sorted { ($0.tryCount, $0.gradeValue) > ($1.tryCount, $1.gradeValue) }
        }
    }

    private static func lastTouched(_ climb: Climb) -> Date {
        (climb.attempts ?? []).map(\.timestamp).max() ?? climb.createdAt
    }
}
