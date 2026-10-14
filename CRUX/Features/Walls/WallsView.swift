import SwiftData
import SwiftUI

/// Every wall at your gym and how fresh its set is.
struct WallsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \Wall.sortOrder) private var allWalls: [Wall]

    @State private var resetting: Wall?
    @State private var resetTick = 0
    @State private var showingNewWall = false
    @State private var newWallName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(walls) { wall in
                        NavigationLink(value: wall) {
                            WallCard(wall: wall) { resetting = wall }
                        }
                        .buttonStyle(.plain)
                    }
                    if walls.isEmpty {
                        ContentUnavailableView("No walls", systemImage: "square.stack.3d.up",
                                               description: Text("Add the walls or sectors your gym resets."))
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.bottom, 24)
                .animation(Theme.spring, value: walls.map(\.id))
            }
            .nightGymBackground()
            .navigationTitle("Walls")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { GymSwitcher() }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("New wall", systemImage: "plus") { showingNewWall = true }
                    SettingsToolbarButton()
                }
            }
            .navigationDestination(for: Wall.self) { WallDetailView(wall: $0) }
            .confirmationDialog(
                "Mark \(resetting?.name ?? "wall") as reset?",
                isPresented: Binding(get: { resetting != nil }, set: { if !$0 { resetting = nil } }),
                titleVisibility: .visible,
                presenting: resetting
            ) { wall in
                Button("Strip \(wall.activeClimbs.count) climbs", role: .destructive) {
                    withAnimation(Theme.spring) { ResetService.reset(wall, in: context) }
                    resetTick += 1
                }
            } message: { _ in
                Text("Climbs on this wall move to Stripped. Their logs and beta stay in your history.")
            }
            .alert("New wall", isPresented: $showingNewWall) {
                TextField("Name", text: $newWallName)
                Button("Add") {
                    let name = newWallName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty, let gym = app.currentGym { app.addWall(named: name, to: gym) }
                    newWallName = ""
                }
                Button("Cancel", role: .cancel) { newWallName = "" }
            }
            .cruxFeedback(.warning, trigger: resetTick)
        }
    }

    private var walls: [Wall] {
        allWalls.filter { $0.gym?.id == app.currentGym?.id }
    }
}

struct WallCard: View {
    let wall: Wall
    let onReset: () -> Void

    var body: some View {
        let active = wall.activeClimbs
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(wall.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(Format.daysAgo(wall.daysSinceReset()))
                        .font(.subheadline)
                        .foregroundStyle(freshness)
                }
                Spacer()
                Button("Reset", systemImage: "arrow.counterclockwise", action: onReset)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.glass)
                    .disabled(active.isEmpty)
                    .accessibilityLabel("Mark \(wall.name) as reset")
            }

            if active.isEmpty {
                Text("Nothing logged on this set yet.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkTertiary)
            } else {
                HStack(spacing: -6) {
                    ForEach(active.sorted { $0.gradeValue < $1.gradeValue }.prefix(9)) { climb in
                        HexBadge(grade: climb.grade, color: climb.holdColor, size: 30, glowing: climb.status.isTopped)
                    }
                    if active.count > 9 {
                        Text("+\(active.count - 9)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.inkSecondary)
                            .padding(.leading, 12)
                    }
                }
                .accessibilityHidden(true)

                Text(summary(active))
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .glassCard(padding: 18)
    }

    private func summary(_ climbs: [Climb]) -> String {
        let sent = climbs.filter(\.hasSent).count
        return "\(climbs.count) since reset · \(sent) sent"
    }

    /// Fresh sets read in the accent; older ones fade.
    private var freshness: Color {
        guard let days = wall.daysSinceReset() else { return Theme.inkTertiary }
        return days <= 7 ? Theme.accent : Theme.inkSecondary
    }
}
