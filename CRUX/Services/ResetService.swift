import Foundation
import SwiftData

enum ResetService {
    /// Marks a wall as reset: every climb currently on it is stripped (archived, history kept)
    /// and a reset entry is recorded. Returns how many climbs were stripped.
    @discardableResult
    static func reset(_ wall: Wall, at date: Date = .now, note: String = "", in context: ModelContext) -> Int {
        let active = (wall.climbs ?? []).filter(\.isActive)
        for climb in active {
            climb.strippedAt = date
        }

        let entry = WallReset(date: date, note: note, strippedCount: active.count)
        context.insert(entry)
        entry.wall = wall
        wall.lastResetAt = date

        try? context.save()
        return active.count
    }
}
