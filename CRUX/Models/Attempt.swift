import Foundation
import SwiftData

nonisolated enum AttemptOutcome: String, Codable {
    case attempt, send
}

nonisolated enum SendType: String, Codable, CaseIterable, Identifiable {
    /// Sent on your very first try.
    case flash
    /// Sent after one or more failed tries.
    case send
    /// Sent again after already sending it.
    case `repeat`

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .flash: "bolt.fill"
        case .send: "checkmark"
        case .repeat: "arrow.trianglehead.2.clockwise"
        }
    }

    /// Infers the send type from the climb's earlier logs (oldest first).
    static func inferred(fromPrior prior: [AttemptOutcome]) -> SendType {
        if prior.contains(.send) { return .repeat }
        return prior.isEmpty ? .flash : .send
    }
}

/// One go on a climb. A send is an attempt whose outcome is `.send`.
@Model
final class Attempt {
    var id: UUID = UUID()
    var timestamp: Date = Date.now
    var outcomeRaw: String = AttemptOutcome.attempt.rawValue
    var sendTypeRaw: String?
    var climb: Climb?
    var session: ClimbSession?

    @Relationship(deleteRule: .nullify, inverse: \BetaMedia.attempt)
    var media: [BetaMedia]? = []

    init(timestamp: Date, outcome: AttemptOutcome, sendType: SendType? = nil) {
        self.timestamp = timestamp
        self.outcomeRaw = outcome.rawValue
        self.sendTypeRaw = sendType?.rawValue
    }

    var outcome: AttemptOutcome {
        get { AttemptOutcome(rawValue: outcomeRaw) ?? .attempt }
        set { outcomeRaw = newValue.rawValue }
    }

    var sendType: SendType? {
        get { sendTypeRaw.flatMap(SendType.init(rawValue:)) }
        set { sendTypeRaw = newValue?.rawValue }
    }

    var isSend: Bool { outcome == .send }
}
