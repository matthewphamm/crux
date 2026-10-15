import Foundation
import Observation
import SwiftData

/// The outcome of a single log, kept so it can be undone and so the UI can celebrate.
struct LogResult {
    let attempt: Attempt
    let climb: Climb
    let sendType: SendType?
    /// True when this was the first send on a climb that had become a project.
    let completedProject: Bool
    /// True when this log opened a new session.
    let startedSession: Bool
}

/// Owns automatic sessions and all attempt/send logging.
///
/// A session opens on the first log and closes after `config.effectiveTimeout` of inactivity.
/// A session that closes on its own ends at its last log, not at the moment the timeout was noticed.
@Observable
final class SessionManager {
    private let context: ModelContext
    private let config: SessionConfig
    private let clock: () -> Date

    private(set) var activeSession: ClimbSession?
    /// The gym new sessions are attributed to.
    var currentGym: Gym?

    init(
        context: ModelContext,
        config: SessionConfig,
        clock: @escaping () -> Date = { .now }
    ) {
        self.context = context
        self.config = config
        self.clock = clock
        refresh()
    }

    // MARK: - Session lifecycle

    /// Closes stale sessions and reloads the open one. Call on launch, on foreground and periodically.
    func refresh() {
        let now = clock()
        var stillOpen: [ClimbSession] = []
        for session in openSessions() {
            if now.timeIntervalSince(session.lastActivityAt) >= config.effectiveTimeout {
                close(session, at: session.lastActivityAt)
            } else {
                stillOpen.append(session)
            }
        }
        // There should only ever be one open session; if older ones linger, close them too.
        for stale in stillOpen.dropFirst() {
            close(stale, at: stale.lastActivityAt)
        }
        activeSession = stillOpen.first
        save()
    }

    /// Climbs added to the running session that haven't been logged yet, newest first.
    private(set) var queuedClimbIDs: [UUID] = []

    /// Starts a session now (from the + button), or returns the one already running.
    @discardableResult
    func startSession() -> ClimbSession {
        let session = sessionForLogging(at: clock()).0
        save()
        return session
    }

    /// Puts a climb on the running session's list before its first log.
    func queue(_ climb: Climb) {
        queuedClimbIDs.removeAll { $0 == climb.id }
        queuedClimbIDs.insert(climb.id, at: 0)
    }

    /// Time until the active session would auto-close, used to schedule the next check.
    var timeUntilAutoClose: TimeInterval? {
        guard let activeSession else { return nil }
        return config.effectiveTimeout - clock().timeIntervalSince(activeSession.lastActivityAt)
    }

    /// Ends the active session now. Returns it for the summary sheet, or nil if it was empty.
    @discardableResult
    func endActiveSession() -> ClimbSession? {
        guard let session = activeSession else { return nil }
        let hadLogs = !(session.attempts ?? []).isEmpty
        close(session, at: clock())
        activeSession = nil
        save()
        return hadLogs ? session : nil
    }

    private func openSessions() -> [ClimbSession] {
        let descriptor = FetchDescriptor<ClimbSession>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func close(_ session: ClimbSession, at date: Date) {
        queuedClimbIDs = []
        if (session.attempts ?? []).isEmpty {
            context.delete(session)
        } else {
            session.endedAt = max(date, session.startedAt)
        }
    }

    private func sessionForLogging(at now: Date) -> (ClimbSession, started: Bool) {
        refresh()
        if let activeSession { return (activeSession, false) }
        let session = ClimbSession(startedAt: now)
        context.insert(session)
        session.gym = currentGym
        activeSession = session
        return (session, true)
    }

    // MARK: - Logging

    @discardableResult
    func log(_ outcome: AttemptOutcome, on climb: Climb, sendType override: SendType? = nil) -> LogResult {
        let now = clock()
        let (session, started) = sessionForLogging(at: now)

        let prior = climb.chronologicalAttempts.map(\.outcome)
        let wasProject = climb.status == .project

        var sendType: SendType?
        if outcome == .send {
            sendType = override ?? SendType.inferred(fromPrior: prior)
        }

        let attempt = Attempt(timestamp: now, outcome: outcome, sendType: sendType)
        context.insert(attempt)
        attempt.climb = climb
        attempt.session = session
        save()

        return LogResult(
            attempt: attempt,
            climb: climb,
            sendType: sendType,
            completedProject: outcome == .send && wasProject && !prior.contains(.send),
            startedSession: started
        )
    }

    /// Reverts a log. If that log opened its session and nothing else was logged, the session goes too.
    func undo(_ result: LogResult) {
        let session = result.attempt.session
        context.delete(result.attempt)
        save()
        if let session, result.startedSession, (session.attempts ?? []).isEmpty {
            context.delete(session)
            if activeSession?.id == session.id { activeSession = nil }
            save()
        }
    }

    /// Changes the send type of an existing send (e.g. the user corrects an inferred flash).
    func setSendType(_ type: SendType, on attempt: Attempt) {
        guard attempt.isSend else { return }
        attempt.sendType = type
        save()
    }

    private func save() {
        try? context.save()
    }
}
