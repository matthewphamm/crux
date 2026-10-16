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
    @State private var opened: Climb?

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
                VStack(alignment: .leading, spacing: 14) {
                    statsStrip

                    if climbs.isEmpty {
                        emptyState
                    } else {
                        HStack {
                            Text("← add a try")
                            Spacer()
                            Text("Tap to open")
                            Spacer()
                            Text("send →")
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkTertiary)
                        .padding(.horizontal, 4)
                        .accessibilityHidden(true)

                        VStack(spacing: 8) {
                            ForEach(climbs) { climb in
                                SwipeLogRow(climb: climb, session: sessions.activeSession) {
                                    opened = climb
                                }
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("End") { confirmingEnd = true }
                        .buttonStyle(PillButtonStyle())
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .logToast()
            .safeAreaInset(edge: .bottom, spacing: 0) { addBar }
            .navigationDestination(item: $opened) { ClimbDetailView(climb: $0) }
            .sheet(isPresented: $showingPicker) {
                ClimbPickerSheet(climbs: gymClimbs, excluding: Set(climbs.map(\.id))) { climb in
                    withAnimation(Theme.spring) { sessions.queue(climb) }
                }
            }
            .sheet(isPresented: $showingNewClimb) {
                ClimbEditorSheet(mode: .create)
            }
            .alert("End this session?", isPresented: $confirmingEnd) {
                Button("Keep climbing", role: .cancel) {}
                Button("End session") { end() }
            } message: {
                Text(endMessage)
            }
            .onChange(of: sessions.activeSession?.id) { _, id in
                // Closed elsewhere (idle timeout, gym switch) — nothing left to show.
                if id == nil, !endingByUser { dismiss() }
            }
        }
    }

    /// Elapsed (amber), tries, sends (green), flashes.
    private var statsStrip: some View {
        let attempts = sessions.activeSession?.attempts ?? []
        let sends = attempts.filter(\.isSend)
        return HStack(spacing: 0) {
            VStack(spacing: 2) {
                if let session = sessions.activeSession {
                    TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                        Text(Format.clock(context.date.timeIntervalSince(session.startedAt)))
                            .font(.number(size: 22))
                            .foregroundStyle(Theme.accent)
                    }
                } else {
                    Text("0:00").font(.number(size: 22)).foregroundStyle(Theme.accent)
                }
                Text("elapsed").font(.system(size: 11)).foregroundStyle(Theme.inkSecondary)
            }
            .frame(maxWidth: .infinity)
            stripStat("\(attempts.count)", "tries")
            stripStat("\(sends.count)", "sends", tint: Theme.send)
            stripStat("\(sends.filter { $0.sendType == .flash }.count)", "flashes")
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).fill(Theme.cardFill))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))
    }

    private func stripStat(_ value: String, _ label: String, tint: Color = Theme.ink) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.number(size: 22))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var addBar: some View {
        HStack(spacing: 12) {
            Button {
                showingPicker = true
            } label: {
                Label("From the wall", systemImage: "square.3.layers.3d")
            }
            .buttonStyle(ControlButtonStyle(ink: Theme.accent))
            .disabled(gymClimbs.isEmpty)

            Button {
                showingNewClimb = true
            } label: {
                Label("New climb", systemImage: "plus")
            }
            .buttonStyle(AccentButtonStyle())
        }
        .padding(.horizontal, Theme.Spacing.gutter)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .background(alignment: .bottom) {
            LinearGradient(colors: [Theme.background.opacity(0), Theme.background.opacity(0.92)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            HexBadge(grade: .three, color: .orange, size: 60, glowing: true)
            Text("What are you trying first?")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Pick a problem that's already on the wall, or add a new one. Every attempt and send lands in this session.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 60)
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
                logger.show(Toast(message: "Nothing logged, so it wasn't saved", symbol: "xmark", tint: Theme.inkSecondary))
                dismiss()
            }
        }
    }

    // MARK: Data

    private var gymClimbs: [Climb] { activeClimbs.inGym(app.currentGym) }

    /// Newest additions on top. Logging never reorders rows, so nothing jumps under your thumb.
    private var climbs: [Climb] {
        guard let session = sessions.activeSession else { return [] }
        let queued = sessions.queuedClimbIDs.compactMap { id in gymClimbs.first { $0.id == id } }
        let added = gymClimbs.filter { $0.createdAt >= session.startedAt }
        var firstLog: [UUID: Date] = [:]
        for attempt in session.attempts ?? [] {
            guard let id = attempt.climb?.id else { continue }
            firstLog[id] = min(firstLog[id] ?? attempt.timestamp, attempt.timestamp)
        }
        let logged = (session.attempts ?? []).compactMap(\.climb).uniqued()
            .sorted { (firstLog[$0.id] ?? .distantPast) > (firstLog[$1.id] ?? .distantPast) }
        return (queued + added + logged).uniqued().filter(\.isActive)
    }
}
