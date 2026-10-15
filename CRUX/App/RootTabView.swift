import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case home, climbs, walls, stats
    /// The middle + button. Never actually selected — it opens the live session.
    case session
}

struct RootTabView: View {
    @Environment(AppModel.self) private var app
    @Environment(SessionManager.self) private var sessions
    @Environment(LogCoordinator.self) private var logger
    @Environment(GymMenuState.self) private var gymMenu
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .home

    var body: some View {
        @Bindable var logger = logger
        TabView(selection: tabSelection) {
            Tab("Home", systemImage: "hexagon.fill", value: .home) {
                HomeView()
            }
            Tab("Climbs", systemImage: "list.bullet.rectangle", value: .climbs) {
                ClimbsView()
            }
            Tab(value: .session) {
                Color.clear
            } label: {
                Label(
                    sessions.activeSession == nil ? "Start" : "Session",
                    systemImage: sessions.activeSession == nil ? "plus.circle.fill" : "record.circle"
                )
            }
            .accessibilityLabel(sessions.activeSession == nil ? "Start session" : "Open session")
            Tab("Walls", systemImage: "square.stack.3d.up", value: .walls) {
                WallsView()
            }
            Tab("Stats", systemImage: "chart.bar.xaxis", value: .stats) {
                StatsView()
            }
        }
        .overlay { GymMenuOverlay() }
        .onChange(of: tab) { gymMenu.isOpen = false }
        .fullScreenCover(isPresented: $logger.isSessionPresented) {
            LiveSessionView()
        }
        .tabBarMinimizeBehavior(.onScrollDown)
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

    /// The middle tab opens the session over whatever tab you're on instead of switching to it.
    private var tabSelection: Binding<AppTab> {
        Binding {
            tab
        } set: { newValue in
            if newValue == .session {
                logger.openSession()
            } else {
                tab = newValue
            }
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
        case "climbs": tab = .climbs
        case "walls": tab = .walls
        case "stats": tab = .stats
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
        Button("Settings", systemImage: "gearshape") { showing = true }
            .sheet(isPresented: $showing) { SettingsView() }
    }
}
