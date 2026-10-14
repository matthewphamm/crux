import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case log, climbs, walls, stats
}

struct RootTabView: View {
    @Environment(SessionManager.self) private var sessions
    @Environment(LogCoordinator.self) private var logger
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .log

    var body: some View {
        TabView(selection: $tab) {
            Tab("Log", systemImage: "hexagon.fill", value: .log) {
                LogView()
            }
            Tab("Climbs", systemImage: "list.bullet.rectangle", value: .climbs) {
                ClimbsView()
            }
            Tab("Walls", systemImage: "square.stack.3d.up", value: .walls) {
                WallsView()
            }
            Tab("Stats", systemImage: "chart.bar.xaxis", value: .stats) {
                StatsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .logFeedback(logger)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { sessions.refresh() }
        }
        .task {
            HapticsService.shared.prepare()
            #if DEBUG
            applyLaunchArguments()
            #endif
            await watchSessionTimeout()
        }
    }

    #if DEBUG
    @Environment(AppModel.self) private var app

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
