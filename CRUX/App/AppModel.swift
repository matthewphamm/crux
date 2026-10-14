import Foundation
import Observation
import SwiftData

/// App-wide state: the store, the session engine and the gym you're climbing at.
@Observable
final class AppModel {
    static let defaultWallNames = ["Cave", "Slab", "Overhang", "Comp wall"]
    static let autoSwitchKey = "app.autoSwitchGym"

    let container: ModelContainer
    let config: SessionConfig
    let sessions: SessionManager
    let locator: GymLocator
    private let defaults: UserDefaults

    private(set) var currentGym: Gym?

    init(container: ModelContainer, defaults: UserDefaults = .standard, clock: @escaping () -> Date = { .now }) {
        self.container = container
        self.defaults = defaults
        self.config = SessionConfig(defaults: defaults)
        self.sessions = SessionManager(context: container.mainContext, config: config, clock: clock)
        self.locator = GymLocator()
        ensureDefaultGym()
    }

    var context: ModelContext { container.mainContext }

    var gyms: [Gym] {
        (try? context.fetch(FetchDescriptor<Gym>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    /// Set from Settings via `@AppStorage(AppModel.autoSwitchKey)`.
    var autoSwitchGym: Bool { defaults.bool(forKey: Self.autoSwitchKey) }

    // MARK: Gyms

    /// Makes `gym` current. You can't be at two gyms at once, so an open session elsewhere wraps up.
    /// Returns the session that was ended, if any.
    @discardableResult
    func select(_ gym: Gym) -> ClimbSession? {
        var ended: ClimbSession?
        if let active = sessions.activeSession, active.gym?.id != gym.id {
            ended = sessions.endActiveSession()
        }
        currentGym = gym
        sessions.currentGym = gym
        defaults.set(gym.id.uuidString, forKey: Self.currentGymKey)
        return ended
    }

    @discardableResult
    func addGym(named name: String, withStarterWalls: Bool = true) -> Gym {
        let gym = Gym(name: name)
        context.insert(gym)
        if withStarterWalls {
            for (index, wallName) in Self.defaultWallNames.enumerated() {
                let wall = Wall(name: wallName, sortOrder: index)
                context.insert(wall)
                wall.gym = gym
            }
        }
        try? context.save()
        return gym
    }

    @discardableResult
    func addWall(named name: String, to gym: Gym) -> Wall {
        let wall = Wall(name: name, sortOrder: (gym.walls ?? []).count)
        context.insert(wall)
        wall.gym = gym
        try? context.save()
        return wall
    }

    /// Deletes a gym with its walls, climbs and sessions. The last gym can't be deleted.
    func delete(_ gym: Gym) {
        let remaining = gyms.filter { $0.id != gym.id }
        guard let fallback = remaining.first else { return }
        if currentGym?.id == gym.id { select(fallback) }
        for wall in gym.walls ?? [] {
            for climb in wall.climbs ?? [] {
                for media in climb.media ?? [] { MediaStore.delete(media.fileName) }
                context.delete(climb)
            }
        }
        for session in gym.sessions ?? [] { context.delete(session) }
        context.delete(gym)
        try? context.save()
        sessions.refresh()
    }

    // MARK: Auto-detect

    /// If auto-switch is on and no session is running, switch to the saved gym you're standing in.
    /// Returns the gym switched to, or nil if nothing changed.
    func autoDetectGym() async -> Gym? {
        guard autoSwitchGym, sessions.activeSession == nil, locator.isAuthorized else { return nil }
        let candidates = gyms.filter { $0.location != nil }
        guard !candidates.isEmpty, let here = await locator.currentLocation() else { return nil }
        guard let gym = GymLocator.nearestGym(to: here, in: candidates), gym.id != currentGym?.id else { return nil }
        // A log may have started a session while we were waiting on GPS.
        guard sessions.activeSession == nil else { return nil }
        select(gym)
        return gym
    }

    /// First launch: create Hive with a few starter walls you can rename.
    private func ensureDefaultGym() {
        let all = gyms
        let storedID = defaults.string(forKey: Self.currentGymKey).flatMap(UUID.init(uuidString:))

        if let gym = all.first(where: { $0.id == storedID }) ?? all.first {
            select(gym)
            return
        }
        select(addGym(named: "Hive Vancouver"))
    }

    private static let currentGymKey = "app.currentGymID"
}
