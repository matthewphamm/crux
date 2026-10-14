import Foundation
import SwiftData

@Model
final class Gym {
    var id: UUID = UUID()
    var name: String = ""
    var gradeSystemID: String = HiveHex.shared.id
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Wall.gym)
    var walls: [Wall]? = []

    @Relationship(deleteRule: .nullify, inverse: \ClimbSession.gym)
    var sessions: [ClimbSession]? = []

    init(name: String) {
        self.name = name
    }

    var sortedWalls: [Wall] {
        (walls ?? []).sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
    }
}
