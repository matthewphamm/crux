import Foundation
import SwiftData

/// A wall or sector that gets reset (stripped and re-set) as a unit.
@Model
final class Wall {
    var id: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date.now
    var lastResetAt: Date?
    var gym: Gym?

    @Relationship(deleteRule: .cascade, inverse: \WallReset.wall)
    var resets: [WallReset]? = []

    @Relationship(deleteRule: .nullify, inverse: \Climb.wall)
    var climbs: [Climb]? = []

    init(name: String, sortOrder: Int = 0) {
        self.name = name
        self.sortOrder = sortOrder
    }

    /// Climbs currently up on the wall (not stripped).
    var activeClimbs: [Climb] {
        (climbs ?? []).filter(\.isActive).sorted { $0.createdAt > $1.createdAt }
    }

    var sortedResets: [WallReset] {
        (resets ?? []).sorted { $0.date > $1.date }
    }

    /// Whole days since the last reset, or nil if it has never been reset.
    func daysSinceReset(now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let lastResetAt else { return nil }
        let start = calendar.startOfDay(for: lastResetAt)
        let end = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: start, to: end).day
    }
}

@Model
final class WallReset {
    var id: UUID = UUID()
    var date: Date = Date.now
    var note: String = ""
    var strippedCount: Int = 0
    var wall: Wall?

    init(date: Date, note: String = "", strippedCount: Int = 0) {
        self.date = date
        self.note = note
        self.strippedCount = strippedCount
    }
}
