import SwiftData
import SwiftUI

/// Home: this week at a glance with one Start button, your projects, and recent sessions.
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
                    Group {
                        if let session = sessions.activeSession {
                            LiveSessionCard(session: session) {
                                logger.openSession()
                            } onEnd: {
                                confirmingEnd = true
                            }
                        } else {
                            WeekCard(sessions: gymSessions) { logger.openSession() }
                        }
                    }
                    .transition(.opacity)

                    if !projects.isEmpty { projectsSection }
                    if !recentSessions.isEmpty { recentSection }
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
                    .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .topBarTrailing) { SettingsToolbarButton() }
                    .sharedBackgroundVisibility(.hidden)
            }
            .cruxTabBar()
            .logToast()
            .navigationDestination(for: Climb.self) { climb in
                ClimbDetailView(climb: climb)
                    .navigationTransition(.zoom(sourceID: climb.id, in: namespace))
            }
            .fullScreenCover(item: $summary) { SessionSummaryView(session: $0) }
            .alert("End this session?", isPresented: $confirmingEnd) {
                Button("Keep climbing", role: .cancel) {}
                Button("End session") { end() }
            } message: {
                Text(endMessage)
            }
        }
    }

    // MARK: Projects

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
            SectionHeader(title: "Projects", trailing: "\(projects.count)")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.cardGap) {
                    ForEach(projects) { climb in
                        NavigationLink(value: climb) {
                            ProjectCard(climb: climb)
                                .matchedTransitionSource(id: climb.id, in: namespace)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, Theme.Spacing.gutter, for: .scrollContent)
            .padding(.horizontal, -Theme.Spacing.gutter)
            .scrollClipDisabled()
        }
    }

    // MARK: Recent sessions

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
            SectionHeader(title: "Recent sessions")
            VStack(spacing: Theme.Spacing.cardGap) {
                ForEach(recentSessions) { session in
                    Button {
                        summary = session
                    } label: {
                        RecentSessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Actions

    private var endMessage: String {
        let logs = sessions.activeSession?.attempts?.count ?? 0
        return logs == 0
            ? "Nothing's been logged yet, so this session won't be saved."
            : "You'll see a summary of your \(logs == 1 ? "1 log" : "\(logs) logs")."
    }

    private func end() {
        withAnimation(Theme.spring) {
            if let ended = sessions.endActiveSession() {
                summary = ended
            } else {
                logger.show(Toast(message: "Nothing logged, so it wasn't saved", symbol: "xmark", tint: Theme.inkSecondary, undo: false))
            }
        }
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

// MARK: - Week card

/// Idle Home card: Mon–Sun hex strip, three stats and the one Start button.
private struct WeekCard: View {
    let sessions: [ClimbSession]
    let onStart: () -> Void

    /// The week runs Monday to Sunday here, whatever the region.
    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    var body: some View {
        let week = StatsService.weekSummary(sessions, now: .now, calendar: calendar)
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "This week")
                Spacer()
                Text(lastLine)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkTertiary)
                    .lineLimit(1)
            }

            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { day in
                    dayCell(day)
                        .frame(maxWidth: .infinity)
                }
            }

            Rectangle().fill(Theme.hairline).frame(height: 1)

            HStack(spacing: 0) {
                stat(value: Text("\(week.sessions)"), label: week.sessions == 1 ? "session" : "sessions")
                divider
                stat(value: Text("\(week.sends)").foregroundStyle(Theme.send), label: week.sends == 1 ? "send" : "sends")
                divider
                stat(
                    value: week.hardestSend.map {
                        Text("\($0)").foregroundStyle(Theme.accent)
                            + Text(" Hex").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.inkSecondary)
                    } ?? Text("—").foregroundStyle(Theme.inkTertiary),
                    label: "hardest"
                )
            }

            Button(action: onStart) {
                Label("Start session", systemImage: "plus")
            }
            .buttonStyle(AccentButtonStyle())
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(LinearGradient(
                    colors: [Theme.accent.opacity(0.11), Color.white.opacity(0.04)],
                    startPoint: .top, endPoint: .bottom
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.accent.opacity(0.18), lineWidth: 1)
        )
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(width: 1, height: 40).padding(.horizontal, 14)
    }

    private func stat(value: Text, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            value
                .font(.number(size: 26))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var weekDays: [Date] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func dayCell(_ day: Date) -> some View {
        let daySessions = sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
        let sends = daySessions.reduce(0) { $0 + (($1.attempts ?? []).filter(\.isSend).count) }
        let isToday = calendar.isDateInToday(day)
        let climbed = !daySessions.isEmpty
        let fill: Color = !climbed ? Theme.emptyCell : (sends >= 3 ? Theme.accent : Theme.accent.opacity(0.55))

        return VStack(spacing: 6) {
            ZStack {
                HexCell().fill(fill)
                if isToday {
                    HexCell().strokeBorderCompat(Theme.accent, lineWidth: 2)
                }
                if climbed {
                    Text("\(sends)")
                        .font(.number(size: 14, weight: .bold))
                        .foregroundStyle(Theme.onAccent)
                }
            }
            .frame(width: 36, height: 32)
            Text(day.formatted(.dateTime.weekday(.narrow)))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isToday ? Theme.accent : Theme.inkTertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide)))\(climbed ? ", \(Format.count(sends, "send"))" : ", no session")")
    }

    private var lastLine: String {
        guard let last = sessions.first else { return "No sessions yet" }
        let sends = (last.attempts ?? []).filter(\.isSend).count
        let day = Format.relativeDay(last.startedAt)
        let label = day == "Today" || day == "Yesterday" ? day.lowercased() : day
        return "Last: \(label) · \(Format.count(sends, "send"))"
    }
}

// MARK: - Live session card

/// Home while climbing: timer, three mini stats, End and Resume.
private struct LiveSessionCard: View {
    let session: ClimbSession
    let onResume: () -> Void
    let onEnd: () -> Void

    var body: some View {
        let attempts = session.attempts ?? []
        let sends = attempts.filter(\.isSend)
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 8, height: 8)
                    .shadow(color: Theme.accent, radius: 4)
                    .symbolEffect(.breathe.pulse, options: .repeat(.continuous))
                Text("Session in progress")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Spacer()
                TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                    Text(Format.clock(context.date.timeIntervalSince(session.startedAt)))
                        .font(.number(size: 17, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
            }

            HStack(spacing: 10) {
                miniStat("\(attempts.count)", "attempts")
                miniStat("\(sends.count)", "sends", tint: Theme.send)
                miniStat("\(Set(attempts.compactMap { $0.climb?.id }).count)", "climbs")
            }

            HStack(spacing: 10) {
                Button("End", action: onEnd)
                    .buttonStyle(ControlButtonStyle())
                Button(action: onResume) {
                    Label("Resume", systemImage: "arrow.up.right")
                        .labelStyle(TrailingIconLabelStyle())
                }
                .buttonStyle(AccentButtonStyle())
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(LinearGradient(
                    colors: [Theme.accent.opacity(0.11), Color.white.opacity(0.04)],
                    startPoint: .top, endPoint: .bottom
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.accent.opacity(0.18), lineWidth: 1)
        )
    }

    private func miniStat(_ value: String, _ label: String, tint: Color = Theme.ink) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.number(size: 22))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.06)))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Project card

private struct ProjectCard: View {
    let climb: Climb

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HexBadge(grade: climb.grade, color: climb.holdColor, size: 52, glowing: true)
            VStack(alignment: .leading, spacing: 3) {
                Text(climb.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text([climb.wall?.name, Format.count(climb.tryCount, "try").replacingOccurrences(of: "trys", with: "tries")]
                    .compactMap(\.self).joined(separator: " · "))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 148, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Recent session row

private struct RecentSessionRow: View {
    let session: ClimbSession

    var body: some View {
        let stats = StatsService.sessionStats(session)
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Format.relativeDay(session.startedAt))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(Format.duration(stats.duration)) · \(Format.count(stats.sends, "send")) · \(Format.tries(stats.attempts))")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer(minLength: 8)
            GradeMiniBars(session: session)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkTertiary)
        }
        .glassCard(padding: 16)
        .accessibilityElement(children: .combine)
    }
}

/// Tries per grade 1–6 as tiny ramp-coloured bars.
struct GradeMiniBars: View {
    let session: ClimbSession

    var body: some View {
        let counts = (1...6).map { grade in
            (session.attempts ?? []).filter { $0.climb?.gradeValue == grade }.count
        }
        let peak = max(counts.max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<6, id: \.self) { index in
                Capsule()
                    .fill(HexGrade(clamping: index + 1).tint)
                    .frame(width: 5, height: 3 + 23 * CGFloat(counts[index]) / CGFloat(peak))
            }
        }
        .frame(height: 26, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

// MARK: - Shapes & styles

/// Small decorative flat-top hex cell (~36×32), as in the week strip and grade ladder.
nonisolated struct HexCell: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path()
        path.move(to: CGPoint(x: r.minX + r.width * 0.25, y: r.minY))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.75, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.75, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX + r.width * 0.25, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.midY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> HexCell {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

extension InsettableShape {
    func strokeBorderCompat(_ color: Color, lineWidth: CGFloat) -> some View {
        strokeBorder(color, lineWidth: lineWidth)
    }
}

/// "Resume ↗": title first, icon after.
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon
        }
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
