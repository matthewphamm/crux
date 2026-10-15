import CoreLocation
import MapKit
import SwiftData
import SwiftUI

/// Rename a gym, pin its location for auto-switching, or delete it.
struct GymDetailView: View {
    @Bindable var gym: Gym

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppModel.self) private var app
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]

    @State private var query = ""
    @State private var results: [GymPlace] = []
    @State private var searching = false
    @State private var locating = false
    @State private var waitingForPermission = false
    @State private var confirmingDelete = false
    @State private var savedTick = 0
    @FocusState private var nameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                nameSection
                locationSection
                if gym.location == nil || !results.isEmpty { searchSection }
                summarySection
                if gyms.count > 1 { deleteButton }
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .nightGymBackground()
        .navigationTitle(gym.name.isEmpty ? "Gym" : gym.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: nameFocused) { _, focused in if !focused { save() } }
        .onDisappear(perform: save)
        .onChange(of: app.locator.authorization) {
            if waitingForPermission, app.locator.isAuthorized {
                waitingForPermission = false
                Task { await useCurrentLocation() }
            }
        }
        .alert("Delete \(gym.name)?", isPresented: $confirmingDelete) {
            Button("Delete gym and its history", role: .destructive) {
                app.delete(gym)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its walls, climbs, sessions and beta are removed from this iPhone.")
        }
        .cruxFeedback(.success, trigger: savedTick)
    }

    // MARK: Sections

    private var nameSection: some View {
        SettingsCard {
            SettingsRow(icon: "building.2.fill", title: "Name") {
                TextField("Gym name", text: $gym.name)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Theme.inkSecondary)
                    .focused($nameFocused)
                    .submitLabel(.done)
            }
        }
        .settingsSection("Gym")
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let location = gym.location {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: location.coordinate, latitudinalMeters: 700, longitudinalMeters: 700
                ))) {
                    Annotation(gym.name, coordinate: location.coordinate) {
                        Hexagon()
                            .fill(Theme.accent)
                            .frame(width: 26, height: 26)
                            .shadow(color: Theme.accent.opacity(0.7), radius: 8)
                    }
                    MapCircle(center: location.coordinate, radius: GymLocator.detectionRadius)
                        .foregroundStyle(Theme.accent.opacity(0.12))
                        .stroke(Theme.accent.opacity(0.5), lineWidth: 1)
                }
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                .allowsHitTesting(false)
                .frame(height: 180)
                .clipShape(.rect(cornerRadius: Theme.Radius.card))
                .id("\(location.coordinate.latitude),\(location.coordinate.longitude)")
                .accessibilityLabel("Map of \(gym.name)")
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            SettingsCard {
                if gym.location != nil {
                    SettingsRow(icon: "mappin.and.ellipse", title: gym.address.isEmpty ? "Location set" : gym.address,
                                subtitle: "Auto-switch triggers within \(Int(GymLocator.detectionRadius)) m")
                }
                Button {
                    Task { await useCurrentLocation() }
                } label: {
                    SettingsRow(icon: "location.fill", title: gym.location == nil ? "Use my current location" : "Update to my current location",
                                subtitle: "Best done while you're at the gym") {
                        if locating { ProgressView() }
                    }
                }
                .buttonStyle(.plain)
                .disabled(locating)
                if gym.location != nil {
                    Button {
                        withAnimation(Theme.spring) { gym.setLocation(nil) }
                        try? context.save()
                    } label: {
                        SettingsRow(icon: "xmark", tint: Theme.inkSecondary, title: "Remove location")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .settingsSection("Location", footer: app.locator.isDenied
            ? "Location access is off for CRUX. — you can still search Apple Maps below."
            : "Used only to recognise this gym when you open the app. Stays on this iPhone.")
        .animation(Theme.spring, value: gym.latitude)
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.inkTertiary)
                TextField("Search Apple Maps, e.g. Hive Surrey", text: $query)
                    .submitLabel(.search)
                    .onSubmit { Task { await search() } }
                if searching { ProgressView() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassEffect(.regular.interactive(), in: .capsule)

            if !results.isEmpty {
                SettingsCard {
                    ForEach(results) { place in
                        Button { choose(place) } label: {
                            SettingsRow(icon: "mappin", tint: Theme.inkSecondary, title: place.name,
                                        subtitle: place.address.isEmpty ? nil : place.address)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity)
            }
        }
        .settingsSection("Find on map")
        .animation(Theme.spring, value: results)
    }

    private var summarySection: some View {
        let walls = gym.walls?.count ?? 0
        let climbs = (gym.walls ?? []).flatMap { $0.climbs ?? [] }
        let sessions = (gym.sessions ?? []).filter { !$0.isOpen }.count
        return SettingsCard {
            SettingsRow(icon: "square.stack.3d.up.fill", tint: Theme.inkSecondary, title: "\(walls) walls",
                        subtitle: "Rename and reset them in the Walls tab")
            SettingsRow(icon: "hexagon.fill", tint: Theme.inkSecondary, title: "\(climbs.filter(\.isActive).count) climbs on the wall",
                        subtitle: "\(climbs.filter { !$0.isActive }.count) stripped · \(sessions) sessions")
        }
        .settingsSection("History")
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            confirmingDelete = true
        } label: {
            Label("Delete gym", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .controlSize(.large)
        .tint(Color(hex: 0xE5534B))
    }

    // MARK: Actions

    private func useCurrentLocation() async {
        let locator = app.locator
        if locator.authorization == .notDetermined {
            waitingForPermission = true
            locator.requestPermission()
            return
        }
        guard locator.isAuthorized else { return }
        locating = true
        defer { locating = false }
        guard let here = await locator.currentLocation() else { return }
        withAnimation(Theme.spring) { gym.setLocation(here.coordinate) }
        try? context.save()
        savedTick += 1
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        searching = true
        defer { searching = false }
        let near = app.locator.isAuthorized ? await app.locator.currentLocation() : nil
        results = await GymLocator.search(text, near: near)
    }

    private func choose(_ place: GymPlace) {
        withAnimation(Theme.spring) {
            gym.setLocation(place.coordinate, address: place.address.isEmpty ? place.name : place.address)
            results = []
            query = ""
        }
        try? context.save()
        savedTick += 1
    }

    private func save() {
        let trimmed = gym.name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { gym.name = "Gym" } else if trimmed != gym.name { gym.name = trimmed }
        try? context.save()
    }
}
