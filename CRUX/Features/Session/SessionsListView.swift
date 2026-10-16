import SwiftUI

/// Session history as a month calendar. Climbing days glow amber; tap one to see its sessions.
struct SessionsListView: View {
    let sessions: [ClimbSession]

    @State private var month: Date = .now
    @State private var selectedDay: Date?
    @State private var direction: Edge = .trailing
    @State private var didSetInitialMonth = false

    private var calendar: Calendar { .current }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                calendarCard

                if let selectedDay {
                    dayDetail(selectedDay)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else if sessions.isEmpty {
                    ContentUnavailableView("No sessions yet", systemImage: "calendar",
                                           description: Text("Sessions appear here once they wrap up."))
                } else {
                    Text("Tap a highlighted day to see that session.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.bottom, 24)
            .animation(Theme.spring, value: selectedDay)
        }
        .nightGymBackground()
        .navigationTitle("Sessions")
        .cruxFeedback(.selection, trigger: selectedDay)
        .cruxFeedback(.selection, trigger: month)
        .onAppear(perform: setInitialMonth)
    }

    // MARK: Calendar

    private var calendarCard: some View {
        VStack(spacing: 14) {
            header
            weekdayRow
            grid
                .id(month)
                .transition(.asymmetric(
                    insertion: .move(edge: direction).combined(with: .opacity),
                    removal: .move(edge: direction == .trailing ? .leading : .trailing).combined(with: .opacity)
                ))
        }
        .glassCard(padding: 16)
        .clipped()
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                if value.translation.width < -40 { step(1) }
                if value.translation.width > 40 { step(-1) }
            }
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.interpolate)
                Text(monthSummary)
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .contentTransition(.numericText())
            }
            Spacer()
            HStack(spacing: 8) {
                Button("Previous month", systemImage: "chevron.left") { step(-1) }
                Button("Next month", systemImage: "chevron.right") { step(1) }
                    .disabled(isCurrentMonth)
            }
            .labelStyle(.iconOnly)
            .font(.subheadline.weight(.semibold))
            .buttonStyle(RoundIconButtonStyle())
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(CalendarMonth.weekdaySymbols(calendar: calendar).enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.inkTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private var grid: some View {
        let days = CalendarMonth.days(in: month, calendar: calendar)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 42)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let daySessions = sessions(on: day)
        let sends = daySessions.reduce(0) { $0 + (($1.attempts ?? []).filter(\.isSend).count) }
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isToday = calendar.isDateInToday(day)
        let hasSession = !daySessions.isEmpty

        return Button {
            guard hasSession else { return }
            withAnimation(Theme.spring) { selectedDay = isSelected ? nil : day }
        } label: {
            ZStack {
                if hasSession {
                    Hexagon()
                        .fill(Theme.accent.opacity(isSelected ? 1 : intensity(sends: sends)))
                        .shadow(color: Theme.accent.opacity(isSelected ? 0.6 : 0), radius: 8)
                        .padding(2)
                }
                if isToday && !isSelected {
                    Hexagon()
                        .stroke(Theme.accent, lineWidth: 1.5)
                        .padding(2)
                }
                Text("\(calendar.component(.day, from: day))")
                    .font(.number(.subheadline, weight: hasSession ? .bold : .regular))
                    .foregroundStyle(dayTextColor(hasSession: hasSession, isSelected: isSelected))
            }
            .frame(height: 42)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
            .scaleEffect(isSelected ? 1.08 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!hasSession)
        .accessibilityLabel(accessibilityLabel(day: day, sessions: daySessions.count, sends: sends))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func dayTextColor(hasSession: Bool, isSelected: Bool) -> Color {
        if isSelected { return Color.black.opacity(0.85) }
        return hasSession ? Theme.ink : Theme.inkTertiary
    }

    /// Busier days glow a little brighter.
    private func intensity(sends: Int) -> Double {
        min(0.28 + Double(sends) * 0.08, 0.7)
    }

    // MARK: Selected day

    private func dayDetail(_ day: Date) -> some View {
        let daySessions = sessions(on: day)
        return VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
            SectionHeader(
                title: day.formatted(.dateTime.weekday(.wide).month(.wide).day()),
                trailing: daySessions.count > 1 ? "\(daySessions.count) sessions" : nil
            )
            ForEach(daySessions) { session in
                NavigationLink(value: session) {
                    SessionRow(session: session, showsTime: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Data & actions

    private func sessions(on day: Date) -> [ClimbSession] {
        sessions
            .filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
            .sorted { $0.startedAt < $1.startedAt }
    }

    private var monthSessions: [ClimbSession] {
        sessions.filter { calendar.isDate($0.startedAt, equalTo: month, toGranularity: .month) }
    }

    private var monthSummary: String {
        let list = monthSessions
        guard !list.isEmpty else { return "No sessions" }
        let sends = list.reduce(0) { $0 + (($1.attempts ?? []).filter(\.isSend).count) }
        return "\(Format.count(list.count, "session")) · \(Format.count(sends, "send"))"
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: .now, toGranularity: .month)
    }

    private func step(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: month) else { return }
        if delta > 0 && calendar.compare(next, to: .now, toGranularity: .month) == .orderedDescending { return }
        direction = delta > 0 ? .trailing : .leading
        withAnimation(Theme.spring) {
            month = next
            selectedDay = nil
        }
    }

    /// Open on the month of your latest session, with that day selected.
    private func setInitialMonth() {
        guard !didSetInitialMonth else { return }
        didSetInitialMonth = true
        if let latest = sessions.max(by: { $0.startedAt < $1.startedAt }) {
            month = latest.startedAt
            selectedDay = calendar.startOfDay(for: latest.startedAt)
        }
    }

    private func accessibilityLabel(day: Date, sessions: Int, sends: Int) -> String {
        let date = day.formatted(date: .complete, time: .omitted)
        guard sessions > 0 else { return date }
        return "\(date), \(Format.count(sessions, "session")), \(Format.count(sends, "send"))"
    }
}

/// Pure month-grid math, kept separate so it can be tested.
enum CalendarMonth {
    /// Days of the month padded with leading nils so the first day lands under its weekday.
    static func days(in month: Date, calendar: Calendar) -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let count = calendar.range(of: .day, in: .month, for: month)?.count else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let days = (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
        return Array(repeating: nil, count: leading) + days
    }

    /// Very short weekday symbols starting from the calendar's first weekday.
    static func weekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }
}

struct SessionRow: View {
    let session: ClimbSession
    /// Under a calendar day the date is already known, so lead with the start time.
    var showsTime = false

    var body: some View {
        let stats = StatsService.sessionStats(session)
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(showsTime
                     ? session.startedAt.formatted(date: .omitted, time: .shortened)
                     : session.startedAt.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("\(Format.duration(stats.duration)) · \(Format.count(stats.attempts, "attempt")) · \(Format.count(stats.sends, "send"))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            if showsTime {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
        .glassCard(padding: 14)
        .accessibilityElement(children: .combine)
    }
}
