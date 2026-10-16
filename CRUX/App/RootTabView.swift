import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case home, climbs, walls, stats
}

struct RootTabView: View {
    @Environment(AppModel.self) private var app
    @Environment(SessionManager.self) private var sessions
    @Environment(LogCoordinator.self) private var logger
    @Environment(GymMenuState.self) private var gymMenu
    @Environment(\.scenePhase) private var scenePhase
    @State private var router = TabRouter()

    var body: some View {
        @Bindable var logger = logger
        TabView(selection: $router.tab) {
            Tab("Home", systemImage: "hexagon.fill", value: AppTab.home) {
                HomeView()
            }
            Tab("Climbs", systemImage: "list.bullet", value: AppTab.climbs) {
                ClimbsView()
            }
            Tab("Walls", systemImage: "square.3.layers.3d", value: AppTab.walls) {
                WallsView()
            }
            Tab("Stats", systemImage: "chart.bar", value: AppTab.stats) {
                StatsView()
            }
        }
        .environment(router)
        .overlay { GymMenuOverlay() }
        .onChange(of: router.tab) { gymMenu.isOpen = false }
        .fullScreenCover(isPresented: $logger.isSessionPresented) {
            LiveSessionView()
        }
        .logFeedback(logger)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            sessions.refresh()
            Task { await detectGym() }
        }
        .task {
            HapticsService.shared.prepare()
            #if DEBUG
            applyLaunchArguments()
            #endif
            await watchSessionTimeout()
        }
    }

    /// Auto-switch to the gym you've just walked into (when enabled and no session is running).
    private func detectGym() async {
        guard let gym = await app.autoDetectGym() else { return }
        logger.show(Toast(message: "You're at \(gym.name)", symbol: "location.fill", tint: Theme.accent, undo: false))
    }

    #if DEBUG
    /// Debug-only hooks for screenshots and UI checks:
    /// `-seedSampleData` loads sample history, `-demoSession` logs a few tries now,
    /// `-tab climbs|walls|stats` opens a tab.
    private func applyLaunchArguments() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "seedSampleData"), let gym = app.currentGym {
            SeedData.loadSample(into: gym, context: app.context)
            sessions.refresh()
        }
        if defaults.bool(forKey: "demoSession") {
            let unsent = (try? app.context.fetch(FetchDescriptor<Climb>()))?
                .filter { $0.isActive && !$0.hasSent }
                .sorted { $0.gradeValue < $1.gradeValue } ?? []
            for (index, climb) in unsent.prefix(3).enumerated() {
                for _ in 0..<(index + 1) { sessions.log(.attempt, on: climb) }
                if index == 0 { sessions.log(.send, on: climb) }
            }
        }
        switch defaults.string(forKey: "tab") {
        case "climbs": router.tab = .climbs
        case "walls": router.tab = .walls
        case "stats": router.tab = .stats
        default: break
        }
    }
    #endif

    /// While the app is open, close the session the moment its idle timeout passes.
    private func watchSessionTimeout() async {
        while !Task.isCancelled {
            let wait = min(max((sessions.timeUntilAutoClose ?? 30) + 0.5, 1), 30)
            try? await Task.sleep(for: .seconds(wait))
            withAnimation(Theme.spring) { sessions.refresh() }
        }
    }
}

/// Settings gear shown in each tab's toolbar.
struct SettingsToolbarButton: View {
    @State private var showing = false

    var body: some View {
        Button { showing = true } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .controlBackground(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
        .fullScreenCover(isPresented: $showing) { SettingsView() }
    }
}
