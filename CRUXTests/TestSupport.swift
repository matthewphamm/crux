import Foundation
import SwiftData
@testable import CRUX

/// A controllable clock for time-dependent logic.
final class TestClock {
    var now: Date

    init(_ now: Date = Date(timeIntervalSince1970: 1_790_000_000)) { self.now = now }

    func advance(minutes: Double) { now = now.addingTimeInterval(minutes * 60) }
    func advance(seconds: Double) { now = now.addingTimeInterval(seconds) }
}

/// A fresh in-memory store plus a session engine wired to a test clock.
struct TestEnvironment {
    let container: ModelContainer
    let clock: TestClock
    let config: SessionConfig
    let sessions: SessionManager
    let gym: Gym
    let wall: Wall

    var context: ModelContext { container.mainContext }

    init(timeoutMinutes: Int = 90) {
        container = CRUXApp.makeContainer(inMemory: true)
        clock = TestClock()
        let defaults = UserDefaults(suiteName: "crux.tests.\(UUID().uuidString)")!
        config = SessionConfig(defaults: defaults)
        config.timeoutMinutes = timeoutMinutes
        let clock = clock
        sessions = SessionManager(context: container.mainContext, config: config, clock: { clock.now })

        gym = Gym(name: "Test Gym")
        container.mainContext.insert(gym)
        wall = Wall(name: "Cave")
        container.mainContext.insert(wall)
        wall.gym = gym
        sessions.currentGym = gym
    }

    @discardableResult
    func climb(_ grade: HexGrade = .three, tags: Set<StyleTag> = [], on wall: Wall? = nil) -> Climb {
        let climb = Climb(grade: grade, holdColor: .blue, styleTags: tags, createdAt: clock.now)
        context.insert(climb)
        climb.wall = wall ?? self.wall
        return climb
    }

    /// Logs `tries` failed attempts, then optionally a send, a minute apart.
    func work(_ climb: Climb, failures: Int, thenSend: Bool) {
        for _ in 0..<failures {
            sessions.log(.attempt, on: climb)
            clock.advance(minutes: 1)
        }
        if thenSend {
            sessions.log(.send, on: climb)
            clock.advance(minutes: 1)
        }
    }

    func allSessions() -> [ClimbSession] {
        (try? context.fetch(FetchDescriptor<ClimbSession>(sortBy: [SortDescriptor(\.startedAt)]))) ?? []
    }
}
