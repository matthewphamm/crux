import Foundation
import SwiftData

enum ResetService {
    /// What a reset changed, so it can be undone exactly.
    struct Record {
        let wall: Wall
        let entry: WallReset
        let stripped: [Climb]
        let previousResetAt: Date?
    }

    /// Marks a wall as reset: every climb currently on it is stripped (archived, history kept)
    /// and a reset entry is recorded.
    @discardableResult
    static func reset(_ wall: Wall, at date: Date = .now, note: String = "", in context: ModelContext) -> Record {
        let active = (wall.climbs ?? []).filter(\.isActive)
        let previous = wall.lastResetAt
        for climb in active {
            climb.strippedAt = date
        }

        let entry = WallReset(date: date, note: note, strippedCount: active.count)
        context.insert(entry)
        entry.wall = wall
        wall.lastResetAt = date

        try? context.save()
        return Record(wall: wall, entry: entry, stripped: active, previousResetAt: previous)
    }

    /// Puts the stripped climbs back on the wall and removes the reset entry.
    static func undo(_ record: Record, in context: ModelContext) {
        for climb in record.stripped { climb.strippedAt = nil }
        record.wall.lastResetAt = record.previousResetAt
        context.delete(record.entry)
        try? context.save()
    }
}
