import Foundation
import Testing
@testable import CRUX

@Suite("Automatic sessions")
@MainActor
struct SessionManagerTests {
    @Test func firstLogStartsSession() {
        let env = TestEnvironment()
        #expect(env.sessions.activeSession == nil)
        let result = env.sessions.log(.attempt, on: env.climb())
        #expect(result.startedSession)
        #expect(env.sessions.activeSession != nil)
        #expect(env.sessions.activeSession?.gym?.id == env.gym.id)
    }

    @Test func logsWithinTimeoutShareSession() {
        let env = TestEnvironment(timeoutMinutes: 90)
        let climb = env.climb()
        env.sessions.log(.attempt, on: climb)
        env.clock.advance(minutes: 89)
        let second = env.sessions.log(.attempt, on: climb)
        #expect(!second.startedSession)
        #expect(env.allSessions().count == 1)
    }

    @Test func idleSessionClosesAtLastLogTime() {
        let env = TestEnvironment(timeoutMinutes: 30)
        let climb = env.climb()
        env.sessions.log(.attempt, on: climb)
        env.clock.advance(minutes: 10)
        env.sessions.log(.send, on: climb)
        let lastLog = env.clock.now

        env.clock.advance(minutes: 45)
        env.sessions.refresh()

        let session = try! #require(env.allSessions().first)
        #expect(env.sessions.activeSession == nil)
        #expect(session.endedAt == lastLog)
    }

    @Test func logAfterTimeoutStartsNewSession() {
        let env = TestEnvironment(timeoutMinutes: 30)
        let climb = env.climb()
        env.sessions.log(.attempt, on: climb)
        env.clock.advance(minutes: 31)
        let result = env.sessions.log(.attempt, on: climb)
        #expect(result.startedSession)
        #expect(env.allSessions().count == 2)
        #expect(env.allSessions().first?.endedAt != nil)
    }

    #if DEBUG
    @Test func debugTimeoutOverrideClosesInSeconds() {
        let env = TestEnvironment(timeoutMinutes: 90)
        env.config.debugTimeout = .thirtySeconds
        env.sessions.log(.attempt, on: env.climb())
        env.clock.advance(seconds: 31)
        env.sessions.refresh()
        #expect(env.sessions.activeSession == nil)
    }
    #endif

    @Test func manualEndReturnsSessionForSummary() {
        let env = TestEnvironment()
        env.sessions.log(.attempt, on: env.climb())
        env.clock.advance(minutes: 5)
        let ended = env.sessions.endActiveSession()
        #expect(ended != nil)
        #expect(ended?.endedAt == env.clock.now)
        #expect(env.sessions.activeSession == nil)
    }

    @Test func undoingOnlyLogRemovesTheSession() {
        let env = TestEnvironment()
        let result = env.sessions.log(.attempt, on: env.climb())
        env.sessions.undo(result)
        #expect(env.sessions.activeSession == nil)
        #expect(env.allSessions().isEmpty)
    }

    @Test func undoKeepsSessionWithOtherLogs() {
        let env = TestEnvironment()
        let climb = env.climb()
        env.sessions.log(.attempt, on: climb)
        let second = env.sessions.log(.attempt, on: climb)
        env.sessions.undo(second)
        #expect(env.sessions.activeSession != nil)
        #expect(climb.tryCount == 1)
    }

    @Test func firstSendOnProjectIsReportedAsCompletion() {
        let env = TestEnvironment()
        let climb = env.climb()
        env.work(climb, failures: Climb.projectThreshold, thenSend: false)
        let send = env.sessions.log(.send, on: climb)
        #expect(send.completedProject)

        let repeatSend = env.sessions.log(.send, on: climb)
        #expect(!repeatSend.completedProject)
        #expect(repeatSend.sendType == .repeat)
    }

    @Test func ordinarySendIsNotAProjectCompletion() {
        let env = TestEnvironment()
        let climb = env.climb()
        env.work(climb, failures: 1, thenSend: false)
        #expect(!env.sessions.log(.send, on: climb).completedProject)
    }
}

@Suite("Wall resets")
@MainActor
struct ResetServiceTests {
    @Test func resetStripsOnlyThatWallsActiveClimbs() {
        let env = TestEnvironment()
        let slab = Wall(name: "Slab")
        env.context.insert(slab)
        slab.gym = env.gym

        let caveClimbs = [env.climb(), env.climb(.five)]
        let slabClimb = env.climb(on: slab)
        let alreadyStripped = env.climb()
        alreadyStripped.strippedAt = env.clock.now.addingTimeInterval(-86_400)
        let originalStrip = alreadyStripped.strippedAt

        env.work(caveClimbs[0], failures: 1, thenSend: true)
        let record = ResetService.reset(env.wall, at: env.clock.now, in: env.context)

        #expect(record.stripped.count == 2)
        #expect(caveClimbs.allSatisfy { !$0.isActive })
        #expect(slabClimb.isActive)
        #expect(alreadyStripped.strippedAt == originalStrip)
        #expect(env.wall.lastResetAt == env.clock.now)
        #expect(env.wall.sortedResets.first?.strippedCount == 2)
        // History is kept.
        #expect(caveClimbs[0].tryCount == 2)
    }

    @Test func undoRestoresClimbsAndPreviousResetDate() {
        let env = TestEnvironment()
        let earlier = env.clock.now.addingTimeInterval(-86_400 * 10)
        env.wall.lastResetAt = earlier
        let climbs = [env.climb(), env.climb(.four)]

        let record = ResetService.reset(env.wall, at: env.clock.now, in: env.context)
        #expect(climbs.allSatisfy { !$0.isActive })

        ResetService.undo(record, in: env.context)
        #expect(climbs.allSatisfy { $0.isActive })
        #expect(env.wall.lastResetAt == earlier)
        #expect(env.wall.sortedResets.isEmpty)
    }

    @Test func daysSinceReset() {
        let env = TestEnvironment()
        #expect(env.wall.daysSinceReset(now: env.clock.now) == nil)
        ResetService.reset(env.wall, at: env.clock.now, in: env.context)
        let later = Calendar.current.date(byAdding: .day, value: 3, to: env.clock.now)!
        #expect(env.wall.daysSinceReset(now: later) == 3)
    }
}
