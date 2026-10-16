import Observation
import SwiftData
import SwiftUI

/// Open/closed state for the gym menu. The pill lives in each tab's toolbar, but the card is
/// drawn once at the root so it can float over everything.
@Observable
final class GymMenuState {
    var isOpen = false
    /// Stats adds an "All gyms" row.
    var offersAllGyms = false

    func toggle(offersAllGyms: Bool) {
        self.offersAllGyms = offersAllGyms
        isOpen.toggle()
    }
}

/// The toolbar pill showing the current gym. Tapping it grows the glass gym card out of it.
struct GymSwitcher: View {
    var offersAllGyms = false

    @Environment(AppModel.self) private var app
    @Environment(GymMenuState.self) private var menu
    @AppStorage("stats.allGyms") private var allGyms = false

    var body: some View {
        Button {
            withAnimation(GymMenuOverlay.spring) { menu.toggle(offersAllGyms: offersAllGyms) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: showsAll ? "square.grid.2x2" : "mappin")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkSecondary)
                    .rotationEffect(.degrees(menu.isOpen ? 180 : 0))
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            .frame(maxWidth: 250)
            .fixedSize(horizontal: true, vertical: false)
            .controlBackground(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Gym: \(title)")
        .accessibilityHint(menu.isOpen ? "Closes the gym list" : "Shows your gyms")
    }

    private var showsAll: Bool { offersAllGyms && allGyms }

    private var title: String {
        showsAll ? "All gyms" : (app.currentGym?.name ?? "Choose gym")
    }
}

/// The floating Liquid Glass card listing your gyms. Attached once, at the root.
struct GymMenuOverlay: View {
    static let spring = Animation.easeOut(duration: 0.22)

    @Environment(GymMenuState.self) private var menu
    @Environment(AppModel.self) private var app
    @Environment(LogCoordinator.self) private var logger
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]
    @AppStorage("stats.allGyms") private var allGyms = false

    @State private var showingManage = false
    @State private var showingNewGym = false
    @State private var newGymName = ""
    @State private var pickTick = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            if menu.isOpen {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)
                    .accessibilityHidden(true)

                card
                    .padding(.leading, Theme.Spacing.gutter)
                    .padding(.top, 50)
                    .transition(
                        .scale(scale: 0.85, anchor: .topLeading)
                            .combined(with: .opacity)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(menu.isOpen)
        .animation(Self.spring, value: menu.isOpen)
        .cruxFeedback(.selection, trigger: menu.isOpen)
        .cruxFeedback(.impact(weight: .light), trigger: pickTick)
        .sheet(isPresented: $showingManage) { SettingsView() }
        .alert("New gym", isPresented: $showingNewGym) {
            TextField("e.g. Hive Surrey", text: $newGymName)
            Button("Add") { addGym() }
            Button("Cancel", role: .cancel) { newGymName = "" }
        } message: {
            Text("It starts with \(AppModel.defaultWallNames.dropLast().joined(separator: ", ")) and \(AppModel.defaultWallNames.last ?? ""). Rename them any time.")
        }
    }

    // MARK: Card

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Climbing at")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSecondary)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 6)

            if menu.offersAllGyms {
                row(
                    icon: AnyView(
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(allGyms ? Theme.accent : Theme.inkSecondary)
                    ),
                    title: "All gyms",
                    subtitle: "Combined progress",
                    isSelected: allGyms
                ) {
                    allGyms = true
                }
            }

            ForEach(gyms) { gym in
                let isCurrent = gym.id == app.currentGym?.id && !(menu.offersAllGyms && allGyms)
                row(
                    icon: AnyView(
                        ZStack {
                            if isCurrent {
                                Hexagon().fill(Theme.accent)
                                    .shadow(color: Theme.accent.opacity(0.6), radius: 6)
                            } else {
                                Hexagon().stroke(Theme.inkTertiary, lineWidth: 1.5)
                            }
                        }
                        .frame(width: 22, height: 22)
                    ),
                    title: gym.name,
                    subtitle: subtitle(for: gym),
                    isSelected: isCurrent
                ) {
                    choose(gym)
                }
            }

            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

            HStack(spacing: 8) {
                footerButton("Add gym", systemImage: "plus") {
                    close()
                    showingNewGym = true
                }
                footerButton("Manage gyms", systemImage: "slider.horizontal.3") {
                    close()
                    showingManage = true
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
        .frame(width: 290)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color(hex: 0x28292E, opacity: 0.94)))
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.55), radius: 25, y: 20)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { close() }
    }

    private func row(
        icon: AnyView, title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                icon.frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.accent.opacity(0.10))
                        .padding(.horizontal, 6)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func footerButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .controlBackground(Capsule())
    }

    private func subtitle(for gym: Gym) -> String {
        if gym.location == nil { return "No location" }
        return gym.address.isEmpty ? "Location set" : gym.address
    }

    // MARK: Actions

    private func close() {
        withAnimation(Self.spring) { menu.isOpen = false }
    }

    private func choose(_ gym: Gym) {
        pickTick += 1
        withAnimation(Theme.spring) {
            if menu.offersAllGyms { allGyms = false }
            if gym.id != app.currentGym?.id, let ended = app.select(gym), let previous = ended.gym {
                logger.show(Toast(message: "Wrapped your session at \(previous.name)", symbol: "flag.checkered", undo: false))
            }
        }
        close()
    }

    private func addGym() {
        let name = newGymName.trimmingCharacters(in: .whitespaces)
        newGymName = ""
        guard !name.isEmpty else { return }
        let gym = app.addGym(named: name)
        choose(gym)
    }
}
