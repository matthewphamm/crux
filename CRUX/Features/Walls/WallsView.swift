import SwiftData
import SwiftUI

/// Every wall at your gym, how fresh its set is, and how much of it you've sent.
struct WallsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(LogCoordinator.self) private var logger
    @Query(sort: \Wall.sortOrder) private var allWalls: [Wall]

    @State private var resetting: Wall?
    @State private var resetTick = 0
    @State private var showingNewWall = false
    @State private var newWallName = ""
    @State private var opened: Climb?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.cardGap) {
                    ForEach(walls) { wall in
                        NavigationLink(value: wall) {
                            WallCard(wall: wall) {
                                resetting = wall
                            } onOpen: { climb in
                                opened = climb
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Button { showingNewWall = true } label: {
                        Label("Add wall", systemImage: "plus")
                    }
                    .buttonStyle(ControlButtonStyle(ink: Theme.accent))
                    .padding(.top, 4)
                }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.bottom, 24)
                .animation(Theme.spring, value: walls.map(\.id))
            }
            .nightGymBackground()
            .navigationTitle("Walls")
            .cruxTabBar()
            .logToast()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { GymSwitcher() }
                ToolbarItem(placement: .topBarTrailing) { SettingsToolbarButton() }
            }
            .navigationDestination(for: Wall.self) { WallDetailView(wall: $0) }
            .navigationDestination(item: $opened) { ClimbDetailView(climb: $0) }
            .alert(
                "Reset \(resetting?.name ?? "wall")?",
                isPresented: Binding(get: { resetting != nil }, set: { if !$0 { resetting = nil } }),
                presenting: resetting
            ) { wall in
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) { reset(wall) }
            } message: { wall in
                Text("Its \(Format.count(wall.activeClimbs.count, "climb")) move to Stripped with their full history.")
            }
            .alert("New wall", isPresented: $showingNewWall) {
                TextField("Name", text: $newWallName)
                Button("Cancel", role: .cancel) { newWallName = "" }
                Button("Add") {
                    let name = newWallName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty, let gym = app.currentGym { app.addWall(named: name, to: gym) }
                    newWallName = ""
                }
            }
            .cruxFeedback(.warning, trigger: resetTick)
        }
    }

    private var walls: [Wall] {
        allWalls.filter { $0.gym?.id == app.currentGym?.id }
    }

    private func reset(_ wall: Wall) {
        let record = withAnimation(Theme.spring) { ResetService.reset(wall, in: context) }
        resetTick += 1
        logger.show(
            Toast(message: "\(wall.name) reset · \(Format.count(record.stripped.count, "climb")) stripped",
                  symbol: "arrow.counterclockwise", tint: Theme.danger)
        ) { [context] in
            ResetService.undo(record, in: context)
        }
    }
}

struct WallCard: View {
    let wall: Wall
    let onReset: () -> Void
    var onOpen: ((Climb) -> Void)? = nil

    var body: some View {
        let active = wall.activeClimbs.sorted { ($0.gradeValue, $0.createdAt) < ($1.gradeValue, $1.createdAt) }
        let sent = active.filter(\.hasSent).count
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(wall.name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(Format.daysAgo(wall.daysSinceReset()))
                        .font(.system(size: 14))
                        .foregroundStyle(isStale ? Theme.danger : Theme.inkSecondary)
                }
                Spacer()
                Button(action: onReset) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .controlBackground(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(active.isEmpty)
                .opacity(active.isEmpty ? 0.4 : 1)
                .accessibilityLabel("Reset \(wall.name)")
            }

            if active.isEmpty {
                Text("Fresh set. Climbs you add here start a new run.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkTertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: -6) {
                        ForEach(active) { climb in
                            Button { onOpen?(climb) } label: {
                                HexBadge(grade: climb.grade, color: climb.holdColor, size: 34)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(climb.displayName)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
                .scrollClipDisabled()

                VStack(spacing: 6) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(Theme.send)
                                .frame(width: proxy.size.width * CGFloat(sent) / CGFloat(max(active.count, 1)))
                        }
                    }
                    .frame(height: 6)
                    HStack {
                        Text("\(active.count) since reset")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.inkSecondary)
                        Spacer()
                        Text("\(sent) sent")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.send)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).fill(Theme.cardFill))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))
    }

    /// Sets older than 60 days are due a reset.
    private var isStale: Bool {
        (wall.daysSinceReset() ?? 0) > 60
    }
}
