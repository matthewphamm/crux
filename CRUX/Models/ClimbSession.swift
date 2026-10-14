import Foundation
import SwiftData

/// A visit to the gym. Started automatically by the first log and closed after a quiet period.
@Model
final class ClimbSession {
    var id: UUID = UUID()
    var startedAt: Date = Date.now
    var endedAt: Date?
    var gym: Gym?

    @Relationship(deleteRule: .cascade, inverse: \Attempt.session)
    var attempts: [Attempt]? = []

    init(startedAt: Date) {
        self.startedAt = startedAt
    }

    var isOpen: Bool { endedAt == nil }

    var chronologicalAttempts: [Attempt] {
        (attempts ?? []).sorted { $0.timestamp < $1.timestamp }
    }

    /// The most recent log, or the start time for an empty session.
    var lastActivityAt: Date {
        (attempts ?? []).map(\.timestamp).max() ?? startedAt
    }

    func duration(now: Date = .now) -> TimeInterval {
        (endedAt ?? now).timeIntervalSince(startedAt)
    }
}
