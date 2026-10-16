import SwiftData
import SwiftUI

/// The session you're climbing right now: add climbs, log tries, end when you're done.
/// Opened from the + button in the tab bar.
struct LiveSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var app
    @Environment(SessionManager.self) private var sessions
    @Environment(LogCoordinator.self) private var logger
    @Query(filter: #Predicate<Climb> { $0.strippedAt == nil }, sort: \Climb.createdAt, order: .reverse)
    private var activeClimbs: [Climb]

    @State private var showingPicker = false
    @State private var showingNewClimb = false
    @State private var confirmingEnd = false
    @State private var ended: ClimbSession?
    @State private var endingByUser = false
    @Namespace private var namespace

    var body: some View {
        if let ended {
            SessionSummaryView(session: ended)
                .transition(.opacity)
        } else {
            live
        }
    }

    private var live: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    SessionHeader(session: sessions.activeSession) { confirmingEnd = true }

                    if climbs.isEmpty {
                        emptyState
                    } else {
                        VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
                            SectionHeader(title: "This session", trailing: "\(climbs.count)")
                            ForEach(climbs) { climb in
                                ClimbLogCard(climb: climb, session: sessions.activeSession, namespace: namespace)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.96).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                        }
                        .animation(Theme.spring, value: climbs.map(\.id))
                    }
                }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .nightGymBackground()
            .navigationTitle(app.currentGym?.name ?? "Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Minimize", systemImage: "chevron.down") { dismiss() }
                        .accessibilityHint("Keeps the session running")
                }
            }
            .logToast()
            .safeAreaInset(edge: .bottom, spacing: 0) { addBar }
            .navigationDestination(for: Climb.self) { climb in
                ClimbDetailView(climb: climb)
                    .navigationTransition(.zoom(sourceID: climb.id, in: namespace))
            }
            .sheet(isPresented: $showingPicker) {
                ClimbPickerSheet(climbs: gymClimbs, excluding: Set(climbs.map(\.id))) { climb in
                    withAnimation(Theme.spring) { sessions.queue(climb) }
                }
            }
            .sheet(isPresented: $showingNewClimb) {
                ClimbEditorSheet(mode: .create)
            }
            .alert("End this session?", isPresented: $confirmingEnd) {
                Button("End session") { end() }
                Button("Keep climbing", role: .cancel) {}
            } message: {
                Text(endMessage)
            }
            .onChange(of: sessions.activeSession?.id) { _, id in
                // Closed elsewhere (idle timeout, gym switch) — nothing left to show.
                if id == nil, !endingByUser { dismiss() }
            }
        }
    }

    private var addBar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    showingPicker = true
                } label: {
                    Label("From the wall", systemImage: "square.stack.3d.up")
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
            LinearGradient(colors: [Theme.background.opacity(0), Theme.background.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            HexBadge(grade: .three, color: .orange, size: 60, glowing: true)
            Text("What are you trying first?")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("Pick a problem that's already on the wall, or add a new one. Every attempt and send lands in this session.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private var endMessage: String {
        let logs = sessions.activeSession?.attempts?.count ?? 0
        return logs == 0
            ? "Nothing's been logged yet, so this session won't be saved."
            : "You'll see a summary of your \(logs == 1 ? "1 log" : "\(logs) logs")."
    }

    private func end() {
        endingByUser = true
        let summary = sessions.endActiveSession()
        withAnimation(Theme.spring) {
            if let summary {
                ended = summary
            } else {
                dismiss()
            }
        }
    }

    // MARK: Data

    private var gymClimbs: [Climb] { activeClimbs.inGym(app.currentGym) }

    /// Most recently logged first, then climbs added but not yet tried.
    private var climbs: [Climb] {
        guard let session = sessions.activeSession else { return [] }
        let logged = (session.attempts ?? [])
            .sorted { $0.timestamp > $1.timestamp }
            .compactMap(\.climb)
        let queued = sessions.queuedClimbIDs.compactMap { id in gymClimbs.first { $0.id == id } }
        let added = gymClimbs.filter { $0.createdAt >= session.startedAt }
        return (queued + added + logged).uniqued().filter(\.isActive)
    }
}
