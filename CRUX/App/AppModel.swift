import Foundation
import Observation
import SwiftData

/// App-wide state: the store, the session engine and the gym you're climbing at.
@Observable
final class AppModel {
    static let defaultWallNames = ["Cave", "Slab", "Overhang", "Comp wall"]

    let container: ModelContainer
    let config: SessionConfig
    let sessions: SessionManager
    private let defaults: UserDefaults

    private(set) var currentGym: Gym?

    init(container: ModelContainer, defaults: UserDefaults = .standard, clock: @escaping () -> Date = { .now }) {
        self.container = container
        self.defaults = defaults
        self.config = SessionConfig(defaults: defaults)
        self.sessions = SessionManager(context: container.mainContext, config: config, clock: clock)
        ensureDefaultGym()
    }

    var context: ModelContext { container.mainContext }

    func select(_ gym: Gym) {
        currentGym = gym
        sessions.currentGym = gym
        defaults.set(gym.id.uuidString, forKey: Self.currentGymKey)
    }

    @discardableResult
    func addGym(named name: String) -> Gym {
        let gym = Gym(name: name)
        context.insert(gym)
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

    /// First launch: create Hive with a few starter walls you can rename.
    private func ensureDefaultGym() {
        let gyms = (try? context.fetch(FetchDescriptor<Gym>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        let storedID = defaults.string(forKey: Self.currentGymKey).flatMap(UUID.init(uuidString:))

        if let gym = gyms.first(where: { $0.id == storedID }) ?? gyms.first {
            select(gym)
            return
        }

        let gym = addGym(named: "Hive Vancouver")
        for name in Self.defaultWallNames {
            addWall(named: name, to: gym)
        }
        select(gym)
    }

    private static let currentGymKey = "app.currentGymID"
}
