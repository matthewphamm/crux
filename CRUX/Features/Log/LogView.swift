import SwiftData
import SwiftUI

/// Home: one-handed logging at the wall.
struct LogView: View {
    @Environment(AppModel.self) private var app
    @Environment(SessionManager.self) private var sessions
    @Query(filter: #Predicate<Climb> { $0.strippedAt == nil }, sort: \Climb.createdAt, order: .reverse)
    private var activeClimbs: [Climb]

    @State private var showingNewClimb = false
    @State private var showingPicker = false
    @State private var summary: ClimbSession?
    @Namespace private var namespace

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    SessionHeader(session: sessions.activeSession) {
                        withAnimation(Theme.spring) { summary = sessions.endActiveSession() }
                    }

                    if !sessionClimbs.isEmpty {
                        section("This session", climbs: sessionClimbs)
                    }
                    if !tickList.isEmpty {
                        section("Tick list", climbs: tickList, trailing: "\(tickList.count)")
                    }
                    if !recentlySet.isEmpty {
                        section("Recently set", climbs: recentlySet)
                    }
                    if gymClimbs.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .nightGymBackground()
            .navigationTitle("CRUX.")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { SettingsToolbarButton() }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
            .logToast()
            .navigationDestination(for: Climb.self) { climb in
                ClimbDetailView(climb: climb)
                    .navigationTransition(.zoom(sourceID: climb.id, in: namespace))
            }
            .sheet(isPresented: $showingNewClimb) {
                ClimbEditorSheet(mode: .create)
            }
            .sheet(isPresented: $showingPicker) {
                ClimbPickerSheet(climbs: gymClimbs)
            }
            .sheet(item: $summary) { session in
                SessionDetailView(session: session, isSummary: true)
            }
        }
    }

    private func section(_ title: String, climbs: [Climb], trailing: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
            SectionHeader(title: title, trailing: trailing)
            ForEach(climbs) { climb in
                ClimbLogCard(climb: climb, session: sessions.activeSession, namespace: namespace)
                    .transition(.asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity), removal: .opacity))
            }
        }
        .animation(Theme.spring, value: climbs.map(\.id))
    }

    private var actionBar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    showingPicker = true
                } label: {
                    Label("Find climb", systemImage: "magnifyingglass")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.glass)
                .disabled(gymClimbs.isEmpty)

                Button {
                    showingNewClimb = true
                } label: {
                    Label("New climb", systemImage: "plus")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.glassProminent)
            }
            .controlSize(.large)
        }
        .padding(.horizontal, Theme.Spacing.gutter)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .background(alignment: .bottom) {
            // Soft fade so cards scrolling underneath don't compete with the buttons.
            LinearGradient(colors: [Theme.background.opacity(0), Theme.background.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            HexBadge(grade: .three, color: .blue, size: 64, glowing: true)
            Text("No climbs yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("Add the problem you're about to try — grade, hold color, wall. Logging it starts your session.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: Data

    private var gymClimbs: [Climb] {
        activeClimbs.inGym(app.currentGym)
    }

    /// Climbs touched this session, most recently logged first, plus climbs added during it.
    private var sessionClimbs: [Climb] {
        guard let session = sessions.activeSession else { return [] }
        let logged = (session.attempts ?? [])
            .sorted { $0.timestamp > $1.timestamp }
            .compactMap(\.climb)
        let added = gymClimbs.filter { $0.createdAt >= session.startedAt }
        return (added + logged).uniqued().filter(\.isActive)
    }

    private var tickList: [Climb] {
        let shown = Set(sessionClimbs.map(\.id))
        return gymClimbs
            .filter { $0.isOnTickList && !$0.hasSent && !shown.contains($0.id) }
            .sorted { $0.gradeValue > $1.gradeValue }
    }

    /// The newest unsent problems, so the next climb is usually one tap away.
    private var recentlySet: [Climb] {
        let shown = Set((sessionClimbs + tickList).map(\.id))
        return Array(gymClimbs.filter { !shown.contains($0.id) && !$0.hasSent }.prefix(4))
    }
}

extension Array where Element == Climb {
    func inGym(_ gym: Gym?) -> [Climb] {
        guard let gym else { return self }
        return filter { $0.wall?.gym?.id == gym.id }
    }

    /// Removes duplicates, keeping first occurrences.
    func uniqued() -> [Climb] {
        var seen = Set<UUID>()
        return filter { seen.insert($0.id).inserted }
    }
}
