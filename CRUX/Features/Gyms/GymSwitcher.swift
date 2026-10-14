import SwiftData
import SwiftUI

/// Toolbar menu showing the current gym; picking another switches the whole app.
/// With `allGyms` bound (Stats), it also offers an "All gyms" scope.
struct GymSwitcher: View {
    var allGyms: Binding<Bool>? = nil

    @Environment(AppModel.self) private var app
    @Environment(LogCoordinator.self) private var logger
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]
    @State private var showingGyms = false
    @State private var switchTick = 0

    var body: some View {
        Menu {
            if let allGyms {
                Button {
                    withAnimation(Theme.spring) { allGyms.wrappedValue = true }
                    switchTick += 1
                } label: {
                    Label("All gyms", systemImage: allGyms.wrappedValue ? "checkmark" : "square.grid.2x2")
                }
                Divider()
            }
            ForEach(gyms) { gym in
                Button {
                    choose(gym)
                } label: {
                    if isSelected(gym) {
                        Label(gym.name, systemImage: "checkmark")
                    } else {
                        Text(gym.name)
                    }
                }
            }
            Divider()
            Button("Manage gyms…", systemImage: "slider.horizontal.3") { showingGyms = true }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: allGyms?.wrappedValue == true ? "square.grid.2x2.fill" : "mappin.circle.fill")
                    .foregroundStyle(Theme.accent)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.inkTertiary)
            }
            .padding(.horizontal, 4)
        }
        .accessibilityLabel("Gym: \(title)")
        .accessibilityHint("Switch gyms")
        .cruxFeedback(.selection, trigger: switchTick)
        .sheet(isPresented: $showingGyms) { SettingsView() }
    }

    private var title: String {
        if allGyms?.wrappedValue == true { return "All gyms" }
        return app.currentGym?.name ?? "Choose gym"
    }

    private func isSelected(_ gym: Gym) -> Bool {
        allGyms?.wrappedValue != true && gym.id == app.currentGym?.id
    }

    private func choose(_ gym: Gym) {
        switchTick += 1
        withAnimation(Theme.spring) {
            allGyms?.wrappedValue = false
            guard gym.id != app.currentGym?.id else { return }
            if let ended = app.select(gym), let previous = ended.gym {
                logger.show(Toast(message: "Wrapped your session at \(previous.name)", symbol: "flag.checkered", undo: false))
            }
        }
    }
}
