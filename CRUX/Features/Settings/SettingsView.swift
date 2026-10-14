import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppModel.self) private var app
    @Environment(SessionConfig.self) private var config
    @Environment(SessionManager.self) private var sessions
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]

    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .dark
    @AppStorage(HapticsService.enabledKey) private var hapticsEnabled = true
    @State private var showingNewGym = false
    @State private var newGymName = ""
    @State private var gymName = ""

    var body: some View {
        @Bindable var config = config
        NavigationStack {
            Form {
                Section("Gym") {
                    Picker("Climbing at", selection: Binding(
                        get: { app.currentGym?.id },
                        set: { id in if let gym = gyms.first(where: { $0.id == id }) { app.select(gym) } }
                    )) {
                        ForEach(gyms) { Text($0.name).tag(Optional($0.id)) }
                    }
                    TextField("Gym name", text: $gymName)
                        .onSubmit(renameGym)
                    Button("Add gym", systemImage: "plus") { showingNewGym = true }
                    LabeledContent("Grading", value: HiveHex.shared.name)
                }

                Section {
                    Stepper(value: $config.timeoutMinutes, in: SessionConfig.timeoutRange, step: 15) {
                        LabeledContent("Auto-end after", value: "\(config.timeoutMinutes) min")
                    }
                } header: {
                    Text("Sessions")
                } footer: {
                    Text("A session starts with your first log and ends on its own after this long without one.")
                }

                Section("Feel") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.label).tag($0) }
                    }
                    Toggle("Haptics", isOn: $hapticsEnabled)
                }

                Section("Hex grades") {
                    ForEach(HexGrade.allCases) { grade in
                        HStack(spacing: 12) {
                            HexBadge(grade: grade, color: .black, size: 28)
                            Text(grade.label)
                            Spacer()
                            Text(grade.vRange).foregroundStyle(.secondary)
                        }
                    }
                }

                #if DEBUG
                DeveloperSection()
                #endif

                Section {
                    LabeledContent("Version", value: Bundle.main.versionString)
                } footer: {
                    Text("CRUX. keeps everything on this iPhone. Hex grade ranges courtesy of Hive Climbing.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(NightGymBackground())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") {
                        renameGym()
                        dismiss()
                    }
                }
            }
            .alert("New gym", isPresented: $showingNewGym) {
                TextField("Name", text: $newGymName)
                Button("Add") {
                    let name = newGymName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty {
                        let gym = app.addGym(named: name)
                        for wall in AppModel.defaultWallNames { app.addWall(named: wall, to: gym) }
                        app.select(gym)
                        gymName = gym.name
                    }
                    newGymName = ""
                }
                Button("Cancel", role: .cancel) { newGymName = "" }
            }
            .onAppear { gymName = app.currentGym?.name ?? "" }
            .onChange(of: app.currentGym?.id) { gymName = app.currentGym?.name ?? "" }
            .onChange(of: config.timeoutMinutes) { sessions.refresh() }
        }
    }

    private func renameGym() {
        let name = gymName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let gym = app.currentGym, gym.name != name else { return }
        gym.name = name
        try? context.save()
    }
}

#if DEBUG
/// Development-only tools. Compiled out of Release builds.
private struct DeveloperSection: View {
    @Environment(\.modelContext) private var context
    @Environment(AppModel.self) private var app
    @Environment(SessionConfig.self) private var config
    @Environment(SessionManager.self) private var sessions
    @State private var confirmingWipe = false

    var body: some View {
        @Bindable var config = config
        Section {
            Picker("Session timeout override", selection: $config.debugTimeout) {
                ForEach(SessionConfig.DebugTimeout.allCases) { Text($0.label).tag($0) }
            }
            .onChange(of: config.debugTimeout) { sessions.refresh() }

            Button("Load sample data", systemImage: "wand.and.stars") {
                guard let gym = app.currentGym else { return }
                _ = sessions.endActiveSession()
                SeedData.loadSample(into: gym, context: context)
                sessions.refresh()
            }
            Button("Shift all data back 1 day", systemImage: "clock.arrow.circlepath") { shiftBack() }
            Button("Play project haptic", systemImage: "sparkles") { HapticsService.shared.playProjectSend() }
            Button("Delete all climbing data", systemImage: "trash", role: .destructive) { confirmingWipe = true }
                .confirmationDialog("Delete all climbs, sessions and walls for this gym?", isPresented: $confirmingWipe,
                                    titleVisibility: .visible) {
                    Button("Delete everything", role: .destructive) {
                        guard let gym = app.currentGym else { return }
                        SeedData.wipe(gym, context: context)
                        for name in AppModel.defaultWallNames { app.addWall(named: name, to: gym) }
                        sessions.refresh()
                    }
                }
        } header: {
            Label("Developer", systemImage: "hammer")
        } footer: {
            Text("Debug builds only. The timeout override makes sessions auto-end in seconds for testing.")
        }
    }

    /// Time travel: moves every timestamp a day earlier to test "yesterday" and reset ages.
    private func shiftBack() {
        let day: TimeInterval = -86_400
        for attempt in (try? context.fetch(FetchDescriptor<Attempt>())) ?? [] { attempt.timestamp += day }
        for session in (try? context.fetch(FetchDescriptor<ClimbSession>())) ?? [] {
            session.startedAt += day
            session.endedAt = session.endedAt.map { $0 + day }
        }
        for climb in (try? context.fetch(FetchDescriptor<Climb>())) ?? [] {
            climb.createdAt += day
            climb.strippedAt = climb.strippedAt.map { $0 + day }
        }
        for wall in (try? context.fetch(FetchDescriptor<Wall>())) ?? [] { wall.lastResetAt = wall.lastResetAt.map { $0 + day } }
        for reset in (try? context.fetch(FetchDescriptor<WallReset>())) ?? [] { reset.date += day }
        try? context.save()
        sessions.refresh()
    }
}
#endif

private extension Bundle {
    var versionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
