import Charts
import SwiftData
import SwiftUI

/// Progress dashboard: where you are, how you're getting there, and what to work on.
struct StatsView: View {
    @Environment(AppModel.self) private var app
    @Query private var allClimbs: [Climb]
    @Query(sort: \ClimbSession.startedAt, order: .reverse) private var allSessions: [ClimbSession]
    @AppStorage("stats.range") private var range: StatsRange = .days90
    @AppStorage("stats.allGyms") private var allGyms = false
    @Query(sort: \Gym.createdAt) private var gyms: [Gym]

    @State private var timeSelection: Date?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    CruxSegmented(options: StatsRange.allCases, selection: $range) { $0.label }

                    currentGradeCard
                    HStack(spacing: Theme.Spacing.cardGap) {
                        StatTile(value: Format.percent(StatsService.flashRate(tops)), caption: "flash rate",
                                 tint: Theme.accent, symbol: "bolt.fill")
                        StatTile(value: Format.decimal(StatsService.averageTriesToSend(tops)), caption: "avg tries to send",
                                 tint: Theme.inkSecondary, symbol: "arrow.2.squarepath")
                    }

                    if tops.isEmpty {
                        ContentUnavailableView(
                            "No sends in this range",
                            systemImage: "chart.bar",
                            description: Text("Your pyramid and trends appear after your first send.")
                        )
                    } else {
                        pyramidCard
                        overTimeCard
                        averageTriesCard
                    }
                    if allGyms && gyms.count > 1 { byGymCard }
                    if !insights.isEmpty { insightsCard }
                    if !styles.isEmpty { styleCard }
                    sessionsLink
                }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.bottom, 24)
            }
            .nightGymBackground()
            .navigationTitle("Progress")
            .cruxTabBar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { GymSwitcher(offersAllGyms: true) }
                    .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .topBarTrailing) { SettingsToolbarButton() }
                    .sharedBackgroundVisibility(.hidden)
            }
            .navigationDestination(for: ClimbSession.self) { SessionSummaryView(session: $0, isCover: false) }
            .navigationDestination(for: SessionsRoute.self) { _ in SessionsListView(sessions: gymSessions) }
            .cruxFeedback(.selection, trigger: range)
        }
    }

    // MARK: Data

    private var now: Date { .now }
    private var start: Date? { range.startDate(from: now) }
    private var climbs: [Climb] { allGyms ? allClimbs : allClimbs.inGym(app.currentGym) }
    private var gymSessions: [ClimbSession] {
        allSessions.filter { !$0.isOpen && (allGyms || $0.gym?.id == app.currentGym?.id) && !($0.attempts ?? []).isEmpty }
    }
    private var tops: [Top] { StatsService.tops(from: climbs, since: start) }
    private var insights: [Insight] { StatsService.insights(climbs, since: start) }
    private var styles: [StyleStat] { StatsService.styleBreakdown(climbs, since: start) }

    // MARK: Current grade

    private var currentGradeCard: some View {
        let current = StatsService.currentGrade(from: climbs, now: now)
        let maxSend = StatsService.maxGrade(StatsService.tops(from: climbs))
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionHeader(title: "Current grade")
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(current.map { "\($0) Hex" } ?? "—")
                            .font(.number(size: 34, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                        if let current {
                            Text(HexGrade(clamping: current).vRange)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(Theme.inkSecondary)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("max send")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSecondary)
                    Text(maxSend.map { "\($0) Hex" } ?? "—")
                        .font(.number(size: 17, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
            }

            GradeLadder(current: current)

            Text(ladderCaption(current))
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).fill(Theme.cardFill))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))
        .animation(Theme.spring, value: current)
    }

    /// "1 of 3 sends needed at 6 Hex in the last 60 days."
    private func ladderCaption(_ current: Int?) -> String {
        let needed = StatsService.currentGradeMinimumSends
        let days = StatsService.currentGradeWindowDays
        let target = min((current ?? 0) + 1, 7)
        if let current, current >= 7 { return "Top of the scale. Keep sending 7 Hex to hold it." }
        let windowStart = Calendar.current.date(byAdding: .day, value: -days, to: now)
        let have = StatsService.tops(from: climbs, since: windowStart).filter { $0.grade == target }.count
        return "\(min(have, needed)) of \(needed) sends needed at \(target) Hex in the last \(days) days."
    }

    // MARK: Pyramid

    private var pyramidCard: some View {
        let maxGrade = StatsService.maxGrade(tops) ?? 1
        let rows = StatsService.pyramid(tops).filter { $0.grade <= maxGrade }.sorted { $0.grade > $1.grade }
        let widest = max(rows.map(\.total).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Grade pyramid", trailing: "\(tops.count) tops")
            VStack(spacing: 8) {
                ForEach(rows) { row in
                    PyramidRowView(row: row, widest: widest)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: rows)
            HStack(spacing: 16) {
                legend("Flash", Theme.Chart.flash)
                legend("Send", Theme.Chart.send)
            }
        }
        .glassCard(padding: 18, radius: Theme.Radius.card)
    }

    private func legend(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.inkSecondary)
        }
    }

    // MARK: Over time

    private var overTimeCard: some View {
        let buckets = StatsService.topsOverTime(tops, bucket: range.bucket)
        let unit: Calendar.Component = range.bucket
        let grades = Array(Set(buckets.map(\.grade))).sorted()
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Sends over time", trailing: range.bucket == .month ? "by month" : "by week")
            Chart {
                ForEach(buckets) { bucket in
                    BarMark(
                        x: .value("Period", bucket.start, unit: unit),
                        y: .value("Sends", bucket.count)
                    )
                    .foregroundStyle(by: .value("Grade", HexGrade(clamping: bucket.grade).label))
                    .cornerRadius(3)
                }
                if let timeSelection,
                   let start = Calendar.current.dateInterval(of: unit, for: timeSelection)?.start {
                    let total = buckets.filter { $0.start == start }.map(\.count).reduce(0, +)
                    RuleMark(x: .value("Period", start, unit: unit))
                        .foregroundStyle(Theme.hairline)
                        .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            VStack(spacing: 2) {
                                Text(start.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(.caption2).foregroundStyle(Theme.inkSecondary)
                                Text("\(total) sends").font(.caption.weight(.semibold)).foregroundStyle(Theme.ink)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0x2C2D32)))
                        }
                }
            }
            .chartForegroundStyleScale(
                domain: grades.map { HexGrade(clamping: $0).label },
                range: grades.map { HexGrade(clamping: $0).tint }
            )
            .chartXSelection(value: $timeSelection)
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(Theme.inkTertiary)
            } }
            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Theme.hairline)
                AxisValueLabel().foregroundStyle(Theme.inkTertiary)
            } }
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 210)
        }
        .glassCard()
    }

    // MARK: Average tries

    private var averageTriesCard: some View {
        let averages = StatsService.averageTriesByGrade(tops)
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Tries to send, by grade")
            Chart(averages) { average in
                BarMark(
                    x: .value("Grade", HexGrade(clamping: average.grade).label),
                    y: .value("Average tries", average.averageTries),
                    width: .ratio(0.55)
                )
                .foregroundStyle(Theme.Chart.send)
                .cornerRadius(4)
                .annotation(position: .top, spacing: 4) {
                    Text(Format.decimal(average.averageTries))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Theme.hairline)
                AxisValueLabel().foregroundStyle(Theme.inkTertiary)
            } }
            .chartXAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(Theme.inkSecondary) } }
            .frame(height: 170)
            .accessibilityLabel("Average tries to send per grade")
        }
        .glassCard()
    }

    // MARK: Insights & style

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
            SectionHeader(title: "Insights")
            ForEach(insights) { insight in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: insight.kind == .weakness ? "scope" : "flame")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(insight.kind == .weakness ? Theme.accent : Theme.send)
                        .frame(width: 22)
                    Text(insight.message)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .glassCard(padding: 14, tint: insight.kind == .weakness ? Theme.accent : nil)
            }
        }
    }

    private var styleCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "By style", trailing: "send rate")
            ForEach(styles.prefix(8)) { stat in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(stat.tag.name).font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
                        Spacer()
                        if let highest = stat.highestSend {
                            Text("best \(HexGrade(clamping: highest).label)")
                                .font(.caption).foregroundStyle(Theme.inkTertiary)
                        }
                        Text(Format.percent(stat.sendRate))
                            .font(.number(.subheadline))
                            .foregroundStyle(Theme.ink)
                            .frame(minWidth: 44, alignment: .trailing)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.surfaceRaised)
                            Capsule().fill(Theme.Chart.send)
                                .frame(width: max(proxy.size.width * stat.sendRate, 4))
                        }
                    }
                    .frame(height: 6)
                    .animation(Theme.spring, value: stat.sendRate)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(stat.tag.name): \(stat.sent) of \(stat.tried) sent")
            }
        }
        .glassCard()
    }

    /// In All-gyms mode: how each location contributes.
    private var byGymCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "By gym", trailing: "tops · sessions")
            ForEach(gyms) { gym in
                let gymTops = StatsService.tops(from: allClimbs.inGym(gym), since: start)
                let sessionCount = gymSessions.filter { $0.gym?.id == gym.id && (start == nil || $0.startedAt >= start!) }.count
                HStack(spacing: 12) {
                    if let best = StatsService.maxGrade(gymTops) {
                        HexBadge(grade: HexGrade(clamping: best), color: .black, size: 30, glowing: true)
                    } else {
                        Hexagon().stroke(Theme.inkTertiary, lineWidth: 1).frame(width: 30, height: 30)
                    }
                    Text(gym.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Spacer()
                    Text("\(gymTops.count) · \(sessionCount)")
                        .font(.number(.subheadline))
                        .foregroundStyle(Theme.inkSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(gym.name): \(gymTops.count) tops, \(sessionCount) sessions")
            }
        }
        .glassCard()
    }

    private var sessionsLink: some View {
        NavigationLink(value: SessionsRoute()) {
            HStack {
                Label("Sessions", systemImage: "calendar")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(gymSessions.count)")
                    .font(.number(.subheadline))
                    .foregroundStyle(Theme.inkSecondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkTertiary)
            }
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}

struct SessionsRoute: Hashable {}

/// Seven hex cells: done grades in ramp colours, the current grade large and amber, the next one hinted.
private struct GradeLadder: View {
    let current: Int?

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            ForEach(HexGrade.allCases) { grade in
                cell(grade.rawValue)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 46)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(current.map { "Current grade \($0) Hex of 7" } ?? "No current grade yet")
    }

    @ViewBuilder
    private func cell(_ grade: Int) -> some View {
        let isCurrent = grade == current
        let isNext = grade == (current ?? 0) + 1
        let below = current.map { grade < $0 } ?? false
        ZStack {
            HexCell()
                .fill(fill(grade, isCurrent: isCurrent, isNext: isNext, below: below))
                .shadow(color: isCurrent ? Theme.accent.opacity(0.55) : .clear, radius: 10)
            if isCurrent || isNext {
                Text("\(grade)")
                    .font(.number(size: isCurrent ? 18 : 13, weight: .bold))
                    .foregroundStyle(isCurrent ? Theme.onAccent : Theme.inkSecondary)
            }
        }
        .frame(width: isCurrent ? 52 : 38, height: isCurrent ? 45 : 33)
    }

    private func fill(_ grade: Int, isCurrent: Bool, isNext: Bool, below: Bool) -> Color {
        if isCurrent { return Theme.accent }
        if below { return HexGrade(clamping: grade).tint }
        if isNext { return Color.white.opacity(0.12) }
        return Color.white.opacity(0.06)
    }
}

/// Centred stacked bar: flash to the left, send to the right, joined at the middle.
private struct PyramidRowView: View {
    let row: PyramidRow
    let widest: Int

    var body: some View {
        HStack(spacing: 10) {
            Text("\(row.grade) Hex")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.inkSecondary)
                .frame(width: 44, alignment: .leading)
            GeometryReader { proxy in
                let unit = proxy.size.width / CGFloat(widest)
                HStack(spacing: 0) {
                    UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 4, style: .continuous)
                        .fill(Theme.Chart.flash)
                        .frame(width: unit * CGFloat(row.flashes))
                    UnevenRoundedRectangle(bottomTrailingRadius: 4, topTrailingRadius: 4, style: .continuous)
                        .fill(Theme.Chart.send)
                        .frame(width: unit * CGFloat(row.sends))
                }
                .frame(width: proxy.size.width)
            }
            .frame(height: 16)
            Text("\(row.total)")
                .font(.number(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 24, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.grade) Hex: \(row.flashes) flashes, \(row.sends) sends")
    }
}
