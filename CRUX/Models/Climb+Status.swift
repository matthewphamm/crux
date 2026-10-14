import Foundation

nonisolated enum ClimbStatus: String, CaseIterable, Identifiable {
    case untried, working, project, sent, flashed

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .untried: "circle.dashed"
        case .working: "circle.lefthalf.filled"
        case .project: "star.fill"
        case .sent: "checkmark.circle.fill"
        case .flashed: "bolt.circle.fill"
        }
    }

    var isTopped: Bool { self == .sent || self == .flashed }
}

extension Climb {
    /// Unsent climbs with this many tries become projects automatically.
    static let projectThreshold = 5

    var chronologicalAttempts: [Attempt] {
        (attempts ?? []).sorted { $0.timestamp < $1.timestamp }
    }

    var tryCount: Int { attempts?.count ?? 0 }

    var firstSend: Attempt? { chronologicalAttempts.first(where: \.isSend) }

    var hasSent: Bool { (attempts ?? []).contains(where: \.isSend) }

    /// Tries up to and including the first send, or nil if not yet sent.
    var triesToFirstSend: Int? {
        let ordered = chronologicalAttempts
        guard let index = ordered.firstIndex(where: \.isSend) else { return nil }
        return index + 1
    }

    var status: ClimbStatus {
        if let firstSend {
            return firstSend.sendType == .flash ? .flashed : .sent
        }
        if isProjectFlagged || tryCount >= Self.projectThreshold { return .project }
        return tryCount > 0 ? .working : .untried
    }

    func tries(in session: ClimbSession) -> Int {
        (attempts ?? []).filter { $0.session?.id == session.id }.count
    }
}
