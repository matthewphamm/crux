import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AppModel.self) private var app
    @Environment(SessionConfig.self) private var config
    @Environment(SessionManager.self) private var sessions
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]

    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .dark
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
                    autoSwitchSection(isOn: $autoSwitchGym)
                    sessionsSection(minutes: $config.timeoutMinutes)
                    feelSection
                    gradesSection
                    #if DEBUG
                    DeveloperSection()
                    #endif
                    about
                }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .nightGymBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Gym.self) { GymDetailView(gym: $0) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                        .buttonStyle(.glassProminent)
                }
            }
            .alert("New gym", isPresented: $showingNewGym) {
                TextField("e.g. Hive Surrey", text: $newGymName)
                Button("Add") { addGym() }
                Button("Cancel", role: .cancel) { newGymName = "" }
            } message: {
                Text("It starts with four placeholder walls you can rename.")
            }
            .onChange(of: config.timeoutMinutes) { sessions.refresh() }
            .cruxFeedback(.selection, trigger: gymTick)
        }
    }

    // MARK: Gyms

    private var gymsSection: some View {
        SettingsCard {
            ForEach(gyms) { gym in
                HStack(spacing: 0) {
                    Button {
                        guard gym.id != app.currentGym?.id else { return }
                        withAnimation(Theme.spring) { _ = app.select(gym) }
                        gymTick += 1
                    } label: {
                        SettingsRow(
                            icon: gym.id == app.currentGym?.id ? "mappin.circle.fill" : "mappin.circle",
                            tint: gym.id == app.currentGym?.id ? Theme.accent : Theme.inkTertiary,
                            title: gym.name,
                            subtitle: subtitle(for: gym)
                        ) {
                            if gym.id == app.currentGym?.id {
                                Text("Here")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Theme.accent.opacity(0.14), in: .capsule)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(gym.id == app.currentGym?.id ? .isSelected : [])

                    NavigationLink(value: gym) {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.inkTertiary)
                            .frame(width: 44, height: 44)
                            .contentShape(.rect)
                    }
                    .padding(.trailing, 6)
                    .accessibilityLabel("Edit \(gym.name)")
                }
            }
            Button { showingNewGym = true } label: {
                SettingsRow(icon: "plus", tint: Theme.inkSecondary, title: "Add gym")
            }
            .buttonStyle(.plain)
        }
        .settingsSection("Gyms", footer: "Tap a gym to climb there. Log, Climbs, Walls and Stats follow the gym you pick.")
    }

    private func subtitle(for gym: Gym) -> String {
        let walls = gym.walls?.count ?? 0
        let place = gym.location == nil ? "No location" : (gym.address.isEmpty ? "Location set" : gym.address)
        return "\(walls) walls · \(place)"
    }

    private func autoSwitchSection(isOn: Binding<Bool>) -> some View {
        let located = gyms.filter { $0.location != nil }.count
        return SettingsCard {
            SettingsRow(
                icon: "location.fill",
                title: "Auto-switch gym",
                subtitle: autoSwitchSubtitle(located: located)
            ) {
                Toggle("Switch gym automatically", isOn: Binding(
                    get: { isOn.wrappedValue },
                    set: { newValue in
                        isOn.wrappedValue = newValue
                        if newValue, app.locator.authorization == .notDetermined { app.locator.requestPermission() }
                    }
                ))
                .labelsHidden()
            }
            if isOn.wrappedValue && app.locator.isDenied {
                Button {
                    if let url = URL(string: "app-settings:") { openURL(url) }
                } label: {
                    SettingsRow(icon: "exclamationmark.triangle.fill", tint: Color(hex: 0xEC8350),
                                title: "Location access is off", subtitle: "Allow “While Using” in iOS Settings.") {
                        Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.inkTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .settingsSection("Arriving", footer: "Checked once when you open CRUX. and never during a session. Your location stays on this iPhone.")
        .animation(Theme.spring, value: isOn.wrappedValue)
    }

    private func autoSwitchSubtitle(located: Int) -> String {
        switch located {
        case 0: "Add a location to a gym first"
        case 1: "1 gym has a location"
        default: "\(located) gyms have a location"
        }
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
        SettingsCard {
            SettingsRow(icon: "timer", title: "Auto-end", subtitle: "after this long without a log") {
                GlassStepper(value: minutes, range: SessionConfig.timeoutRange, step: 15) { "\($0) min" }
            }
        }
        .settingsSection("Sessions", footer: "A session starts with your first log and ends at your last one once you've been quiet this long.")
    }

    // MARK: Feel

    private var feelSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ForEach(Appearance.allCases) { option in
                    AppearanceTile(option: option, isSelected: appearance == option) {
                        withAnimation(Theme.spring) { appearance = option }
                    }
                }
            }
            .cruxFeedback(.selection, trigger: appearance)

            SettingsCard {
                SettingsRow(icon: "hand.tap.fill", title: "Haptics", subtitle: "Taps for logs, a pattern for projects") {
                    Toggle("Haptics", isOn: $hapticsEnabled).labelsHidden()
                }
            }
        }
        .settingsSection("Look & feel")
    }

    // MARK: Grades

    private var gradesSection: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(HexGrade.allCases) { grade in
                VStack(spacing: 6) {
                    HexBadge(grade: grade, color: .black, size: 34)
                    Text(grade.vRange)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.card))
        .settingsSection("Hex grades", footer: "\(HiveHex.shared.name). V ranges are Hive's published approximations.")
    }

    // MARK: About

    private var about: some View {
        VStack(spacing: 8) {
            Hexagon()
                .stroke(Theme.accent, lineWidth: 3)
                .frame(width: 30, height: 30)
                .shadow(color: Theme.accent.opacity(0.6), radius: 8)
            Text("CRUX.")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text("Version \(Bundle.main.versionString)")
                .font(.caption)
                .foregroundStyle(Theme.inkTertiary)
            Text("Everything stays on this iPhone.\nHex grade ranges courtesy of Hive Climbing.")
                .font(.caption)
                .foregroundStyle(Theme.inkTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

/// Appearance choice shown as a tiny preview of the theme.
private struct AppearanceTile: View {
    let option: Appearance
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                preview
                    .frame(height: 54)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
                Text(option.label)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.inkSecondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .glassEffect(isSelected ? .regular.tint(Theme.accent.opacity(0.16)).interactive() : .regular.interactive(),
                         in: .rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(isSelected ? Theme.accent.opacity(0.6) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.label) appearance")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var preview: some View {
        switch option {
        case .dark: swatch(background: Color(hex: 0x121315), bar: Color(hex: 0x2A2B30))
        case .light: swatch(background: Color(hex: 0xF3F2EF), bar: Color(hex: 0xDEDCD7))
        case .system:
            HStack(spacing: 0) {
                swatch(background: Color(hex: 0xF3F2EF), bar: Color(hex: 0xDEDCD7))
                swatch(background: Color(hex: 0x121315), bar: Color(hex: 0x2A2B30))
            }
        }
    }

    private func swatch(background: Color, bar: Color) -> some View {
        ZStack(alignment: .topLeading) {
            background
            VStack(alignment: .leading, spacing: 5) {
                Hexagon().fill(Color(hex: 0xF2B45A)).frame(width: 12, height: 12)
                Capsule().fill(bar).frame(width: 34, height: 5)
                Capsule().fill(bar).frame(width: 22, height: 5)
            }
            .padding(8)
        }
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
        .confirmationDialog("Replace this gym's data with sample history?", isPresented: $confirmingSeed, titleVisibility: .visible) {
            Button("Load sample data", role: .destructive) {
                guard let gym = app.currentGym else { return }
                _ = sessions.endActiveSession()
                SeedData.loadSample(into: gym, context: context)
                sessions.refresh()
            }
        }
        .confirmationDialog("Delete all climbs, sessions and walls for this gym?", isPresented: $confirmingWipe,
                            titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) {
                guard let gym = app.currentGym else { return }
                SeedData.wipe(gym, context: context)
                for name in AppModel.defaultWallNames { app.addWall(named: name, to: gym) }
                sessions.refresh()
            }
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
