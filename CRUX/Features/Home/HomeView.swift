import SwiftData
import SwiftUI

/// Home: your session at a glance, what you're working toward, and recent sessions.
/// Logging happens in the live session, opened with the + button.
struct HomeView: View {
    @Environment(AppModel.self) private var app
    @Environment(SessionManager.self) private var sessions
    @Environment(LogCoordinator.self) private var logger
    @Query(filter: #Predicate<Climb> { $0.strippedAt == nil }, sort: \Climb.createdAt, order: .reverse)
    private var activeClimbs: [Climb]
    @Query(sort: \ClimbSession.startedAt, order: .reverse) private var allSessions: [ClimbSession]

    @State private var summary: ClimbSession?
    @State private var confirmingEnd = false
    @Namespace private var namespace

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    if let session = sessions.activeSession {
                        ActiveSessionCard(session: session) {
                            logger.openSession()
                        } onEnd: {
                            confirmingEnd = true
                        }
                    } else {
                        weekCard
                    }

                    if !projects.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
                            SectionHeader(title: "Projects", trailing: "\(projects.count)")
                            ForEach(projects) { climb in
                                NavigationLink(value: climb) {
                                    ClimbRow(climb: climb)
                                        .matchedTransitionSource(id: climb.id, in: namespace)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !recentSessions.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
                            SectionHeader(title: "Recent sessions")
                            ForEach(recentSessions) { session in
                                NavigationLink(value: session) { SessionRow(session: session) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .animation(Theme.spring, value: sessions.activeSession?.id)
            }
            .nightGymBackground()
            .navigationTitle("CRUX.")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { GymSwitcher() }
                ToolbarItem(placement: .topBarTrailing) { SettingsToolbarButton() }
            }
            .logToast()
            .cruxTabBar()
            .navigationDestination(for: Climb.self) { climb in
                ClimbDetailView(climb: climb)
                    .navigationTransition(.zoom(sourceID: climb.id, in: namespace))
            }
            .navigationDestination(for: ClimbSession.self) { SessionDetailView(session: $0) }
            .sheet(item: $summary) { SessionDetailView(session: $0, isSummary: true) }
            .alert("End this session?", isPresented: $confirmingEnd) {
                Button("End session") {
                    withAnimation(Theme.spring) { summary = sessions.endActiveSession() }
                }
                Button("Keep climbing", role: .cancel) {}
            } message: {
                Text(endMessage)
            }
        }
    }

    /// When you're not climbing: how this week is going, at a glance.
    private var weekCard: some View {
        let week = StatsService.weekSummary(gymSessions, now: .now)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "This week")
            HStack(spacing: 10) {
                StatTile(value: "\(week.sessions)", caption: week.sessions == 1 ? "session" : "sessions", symbol: "calendar")
                StatTile(value: "\(week.sends)", caption: week.sends == 1 ? "send" : "sends", tint: Theme.send, symbol: "checkmark")
                hardestTile(week.hardestSend)
            }
            Text(lastSessionLine)
                .font(.footnote)
                .foregroundStyle(Theme.inkTertiary)
                .padding(.horizontal, 4)
        }
    }

    private func hardestTile(_ grade: Int?) -> some View {
        StatTile(value: grade.map { "\($0) Hex" } ?? "—", caption: "hardest", tint: Theme.accent, symbol: "hexagon.fill")
    }

    private var lastSessionLine: String {
        guard let last = gymSessions.first else { return "No sessions yet — tap ＋ to start one." }
        let sends = (last.attempts ?? []).filter(\.isSend).count
        let day = Calendar.current.isDateInToday(last.startedAt) ? "today"
            : Calendar.current.isDateInYesterday(last.startedAt) ? "yesterday"
            : last.startedAt.formatted(.dateTime.weekday(.wide))
        return "Last session \(day) · \(Format.count(sends, "send"))"
    }

    private var endMessage: String {
        let logs = sessions.activeSession?.attempts?.count ?? 0
        return logs == 0
            ? "Nothing's been logged yet, so this session won't be saved."
            : "You'll see a summary of your \(logs == 1 ? "1 log" : "\(logs) logs")."
    }

    // MARK: Data

    /// Unsent projects on the wall — starred, or 5+ tries without a send.
    private var projects: [Climb] {
        activeClimbs.inGym(app.currentGym)
            .filter { $0.status == .project }
            .sorted { ($0.gradeValue, $0.tryCount) > ($1.gradeValue, $1.tryCount) }
    }

    /// Finished, non-empty sessions at this gym, newest first.
    private var gymSessions: [ClimbSession] {
        allSessions.filter { !$0.isOpen && $0.gym?.id == app.currentGym?.id && !($0.attempts ?? []).isEmpty }
    }

    private var recentSessions: [ClimbSession] { Array(gymSessions.prefix(3)) }
}

/// The running session, with Resume and End.
private struct ActiveSessionCard: View {
    let session: ClimbSession
    let onResume: () -> Void
    let onEnd: () -> Void

    var body: some View {
        let attempts = session.attempts ?? []
        let sends = attempts.filter(\.isSend)
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.accent)
                    .symbolEffect(.breathe.pulse, options: .repeat(.continuous))
                Text("Session in progress")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Spacer()
                TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                    Text(Format.clock(context.date.timeIntervalSince(session.startedAt)))
                        .font(.number(.subheadline))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                }
            }

            HStack(spacing: 10) {
                StatTile(value: "\(attempts.count)", caption: "attempts", symbol: "hand.raised.fill")
                StatTile(value: "\(sends.count)", caption: "sends", tint: Theme.send, symbol: "checkmark")
                StatTile(value: "\(Set(attempts.compactMap { $0.climb?.id }).count)", caption: "climbs", symbol: "hexagon")
            }

            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    Button(action: onEnd) {
                        Text("End").font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.glass)

                    Button(action: onResume) {
                        Label("Resume", systemImage: "arrow.up.forward")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.glassProminent)
                }
                .controlSize(.large)
            }
        }
        .glassCard(padding: 18, tint: Theme.accent)
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
