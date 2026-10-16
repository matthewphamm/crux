import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AppModel.self) private var app
    @Environment(SessionConfig.self) private var config
    @Environment(SessionManager.self) private var sessions
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]

    @AppStorage(HapticsService.enabledKey) private var hapticsEnabled = true
    @AppStorage(AppModel.autoSwitchKey) private var autoSwitchGym = false
    @State private var showingNewGym = false
    @State private var newGymName = ""
    @State private var gymTick = 0

    var body: some View {
        @Bindable var config = config
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    gymsSection
                    sessionsSection(minutes: $config.timeoutMinutes)
                    gradesSection
                    #if DEBUG
                    DeveloperSection()
                    #endif
                    Text("CRUX. keeps everything on this iPhone. No account, no backend.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkTertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    Text("Version \(Bundle.main.versionString)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkTertiary)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .nightGymBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Gym.self) { GymDetailView(gym: $0) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(PillButtonStyle(filled: true))
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .alert("New gym", isPresented: $showingNewGym) {
                TextField("e.g. Hive Surrey", text: $newGymName)
                Button("Cancel", role: .cancel) { newGymName = "" }
                Button("Add") { addGym() }
            } message: {
                Text("It starts with \(AppModel.defaultWallNames.dropLast().joined(separator: ", ")) and \(AppModel.defaultWallNames.last ?? ""). Rename them any time.")
            }
            .onChange(of: config.timeoutMinutes) { sessions.refresh() }
            .cruxFeedback(.selection, trigger: gymTick)
        }
    }

    // MARK: Gyms

    private var gymsSection: some View {
        SettingsCard {
            ForEach(gyms) { gym in
                let isCurrent = gym.id == app.currentGym?.id
                HStack(spacing: 0) {
                    Button {
                        guard !isCurrent else { return }
                        withAnimation(Theme.spring) { _ = app.select(gym) }
                        gymTick += 1
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "mappin")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(isCurrent ? Theme.onAccent : Theme.inkSecondary)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(isCurrent ? Theme.accent : Theme.controlFill))
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(gym.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                        .lineLimit(1)
                                    if isCurrent {
                                        Text("Here")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Theme.accent)
                                            .padding(.horizontal, 7).padding(.vertical, 2)
                                            .background(Theme.accent.opacity(0.16), in: .capsule)
                                    }
                                }
                                Text(subtitle(for: gym))
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.inkSecondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                        }
                        .padding(.leading, 16)
                        .padding(.vertical, 12)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isCurrent ? .isSelected : [])

                    NavigationLink(value: gym) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.inkTertiary)
                            .frame(width: 44, height: 44)
                            .contentShape(.rect)
                    }
                    .padding(.trailing, 6)
                    .accessibilityLabel("Edit \(gym.name)")
                }
            }
            Button { showingNewGym = true } label: {
                Label("Add gym", systemImage: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 50)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .settingsSection("Gyms")
    }

    private func subtitle(for gym: Gym) -> String {
        let walls = gym.walls?.count ?? 0
        let place = gym.location == nil ? "No location" : (gym.address.isEmpty ? "Location set" : gym.address)
        return "\(Format.count(walls, "wall")) · \(place)"
    }

    private func addGym() {
        let name = newGymName.trimmingCharacters(in: .whitespaces)
        newGymName = ""
        guard !name.isEmpty else { return }
        let gym = app.addGym(named: name)
        withAnimation(Theme.spring) { _ = app.select(gym) }
        gymTick += 1
    }

    // MARK: Sessions

    private func sessionsSection(minutes: Binding<Int>) -> some View {
        let located = gyms.filter { $0.location != nil }.count
        return SettingsCard {
            SettingsRow(icon: "timer", title: "Auto-end after", subtitle: "With no logs for this long") {
                GlassStepper(value: minutes, range: SessionConfig.timeoutRange, step: 15) { "\($0) min" }
            }
            SettingsRow(
                icon: "location",
                title: "Switch gym automatically",
                subtitle: located == 1 ? "1 gym has a location" : "\(located) gyms have a location"
            ) {
                Toggle("Switch gym automatically", isOn: Binding(
                    get: { autoSwitchGym },
                    set: { newValue in
                        autoSwitchGym = newValue
                        if newValue, app.locator.authorization == .notDetermined { app.locator.requestPermission() }
                    }
                ))
                .labelsHidden()
                .tint(Theme.accent)
            }
            if autoSwitchGym && app.locator.isDenied {
                Button {
                    if let url = URL(string: "app-settings:") { openURL(url) }
                } label: {
                    SettingsRow(icon: "exclamationmark.triangle.fill", tint: Theme.danger,
                                title: "Location access is off", subtitle: "Allow “While Using” in iOS Settings.") {
                        Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.inkTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            SettingsRow(icon: "hand.tap", title: "Haptics", subtitle: "A tap for every log") {
                Toggle("Haptics", isOn: $hapticsEnabled)
                    .labelsHidden()
                    .tint(Theme.accent)
            }
        }
        .settingsSection("Sessions")
        .animation(Theme.spring, value: autoSwitchGym)
    }

    // MARK: Grades

    private var gradesSection: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(HexGrade.allCases) { grade in
                VStack(spacing: 6) {
                    HexBadge(grade: grade, color: .black, size: 38)
                    Text(grade.vRange)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).fill(Theme.cardFill))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))
        .settingsSection("Hex grades")
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
    @State private var confirmingSeed = false

    var body: some View {
        @Bindable var config = config
        SettingsCard {
            SettingsRow(icon: "timer", tint: Theme.inkSecondary, title: "Timeout override") {
                Picker("Timeout", selection: $config.debugTimeout) {
                    ForEach(SessionConfig.DebugTimeout.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .onChange(of: config.debugTimeout) { sessions.refresh() }
            }
            Button { confirmingSeed = true } label: {
                SettingsRow(icon: "wand.and.stars", tint: Theme.inkSecondary, title: "Load sample data",
                            subtitle: "Replaces this gym's climbs and sessions")
            }
            .buttonStyle(.plain)
            Button(action: shiftBack) {
                SettingsRow(icon: "clock.arrow.circlepath", tint: Theme.inkSecondary, title: "Shift all data back 1 day")
            }
            .buttonStyle(.plain)
            Button { HapticsService.shared.playProjectSend() } label: {
                SettingsRow(icon: "sparkles", tint: Theme.inkSecondary, title: "Play project haptic")
            }
            .buttonStyle(.plain)
            Button { confirmingWipe = true } label: {
                SettingsRow(icon: "trash", tint: Color(hex: 0xE5534B), title: "Delete this gym's climbing data")
            }
            .buttonStyle(.plain)
        }
        .settingsSection("Developer", footer: "Debug builds only. The timeout override makes sessions auto-end in seconds for testing.")
        .alert("Replace this gym's data with sample history?", isPresented: $confirmingSeed) {
            Button("Load sample data", role: .destructive) {
                guard let gym = app.currentGym else { return }
                _ = sessions.endActiveSession()
                SeedData.loadSample(into: gym, context: context)
                sessions.refresh()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete all climbs, sessions and walls for this gym?", isPresented: $confirmingWipe) {
            Button("Delete everything", role: .destructive) {
                guard let gym = app.currentGym else { return }
                SeedData.wipe(gym, context: context)
                for name in AppModel.defaultWallNames { app.addWall(named: name, to: gym) }
                sessions.refresh()
            }
            Button("Cancel", role: .cancel) {}
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

extension Bundle {
    var versionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
