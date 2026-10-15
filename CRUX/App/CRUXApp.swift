import SwiftData
import SwiftUI

@main
struct CRUXApp: App {
    @State private var app: AppModel
    @State private var logger: LogCoordinator
    @State private var gymMenu = GymMenuState()
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .dark

    init() {
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let container = Self.makeContainer(inMemory: isTesting)
        let app = AppModel(container: container)
        _app = State(initialValue: app)
        _logger = State(initialValue: LogCoordinator(sessions: app.sessions))
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(app)
                .environment(app.sessions)
                .environment(app.config)
                .environment(logger)
                .environment(gymMenu)
                .modelContainer(app.container)
                .preferredColorScheme(appearance.colorScheme)
                .tint(Theme.accent)
        }
    }

    static func makeContainer(inMemory: Bool) -> ModelContainer {
        let schema = Schema([
            Gym.self, Wall.self, WallReset.self, Climb.self, Attempt.self, ClimbSession.self, BetaMedia.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Could not open the CRUX. store: \(error)")
        }
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case dark, light, system

    static let storageKey = "app.appearance"

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}
