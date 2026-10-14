import Charts
import SwiftData
import SwiftUI

/// Progress dashboard: where you are, how you're getting there, and what to work on.
struct StatsView: View {
    @Environment(AppModel.self) private var app
    @Query private var allClimbs: [Climb]
    @Query(sort: \ClimbSession.startedAt, order: .reverse) private var allSessions: [ClimbSession]
    @AppStorage("stats.range") private var range: StatsRange = .days90

    @State private var pyramidSelection: String?
    @State private var timeSelection: Date?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    Picker("Range", selection: $range.animation(Theme.spring)) {
                        ForEach(StatsRange.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    headline

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
                    if !insights.isEmpty { insightsCard }
                    if !styles.isEmpty { styleCard }
                    sessionsLink
                }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.bottom, 24)
            }
            .nightGymBackground()
            .navigationTitle("Progress")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SettingsToolbarButton() } }
            .navigationDestination(for: ClimbSession.self) { SessionDetailView(session: $0) }
            .navigationDestination(for: SessionsRoute.self) { _ in SessionsListView(sessions: gymSessions) }
            .cruxFeedback(.selection, trigger: range)
        }
    }

    // MARK: Data

    private var now: Date { .now }
    private var start: Date? { range.startDate(from: now) }
    private var climbs: [Climb] { allClimbs.inGym(app.currentGym) }
    private var gymSessions: [ClimbSession] {
        allSessions.filter { !$0.isOpen && $0.gym?.id == app.currentGym?.id && !($0.attempts ?? []).isEmpty }
    }
    private var tops: [Top] { StatsService.tops(from: climbs, since: start) }
    private var insights: [Insight] { StatsService.insights(climbs, since: start) }
    private var styles: [StyleStat] { StatsService.styleBreakdown(climbs, since: start) }

    // MARK: Headline

    private var headline: some View {
        let current = StatsService.currentGrade(from: climbs, now: now)
        let max = StatsService.maxGrade(StatsService.tops(from: climbs))
        return Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                gradeTile(current, caption: "current grade", footnote: "3+ sends, 60 days")
                gradeTile(max, caption: "max send", footnote: "all time")
            }
            GridRow {
                StatTile(value: Format.percent(StatsService.flashRate(tops)), caption: "flash rate",
                         tint: Theme.Chart.flash, symbol: "bolt.fill")
                StatTile(value: Format.decimal(StatsService.averageTriesToSend(tops)), caption: "avg tries to send",
                         symbol: "repeat")
            }
        }
    }

    private func gradeTile(_ grade: Int?, caption: String, footnote: String) -> some View {
        HStack(spacing: 12) {
            if let grade {
                HexBadge(grade: HexGrade(clamping: grade), color: .black, size: 40, glowing: true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(grade.map { HexGrade(clamping: $0).vRange } ?? "—")
                    .font(.number(.headline))
                    .foregroundStyle(Theme.ink)
                Text(caption).font(.caption).foregroundStyle(Theme.inkSecondary)
                Text(footnote).font(.caption2).foregroundStyle(Theme.inkTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 14)
        .accessibilityElement(children: .combine)
    }

    // MARK: Pyramid

    private var pyramidCard: some View {
        let rows = StatsService.pyramid(tops).filter { $0.total > 0 || $0.grade <= (StatsService.maxGrade(tops) ?? 1) }
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Grade pyramid", trailing: "\(tops.count) tops")
            Chart {
                ForEach(rows) { row in
                    BarMark(x: .value("Count", row.flashes), y: .value("Grade", HexGrade(clamping: row.grade).label))
                        .foregroundStyle(by: .value("Type", "Flash"))
                        .cornerRadius(4)
                    BarMark(x: .value("Count", row.sends), y: .value("Grade", HexGrade(clamping: row.grade).label))
                        .foregroundStyle(by: .value("Type", "Send"))
                        .cornerRadius(4)
                }
                if let pyramidSelection, let row = rows.first(where: { HexGrade(clamping: $0.grade).label == pyramidSelection }) {
                    RuleMark(y: .value("Grade", pyramidSelection))
                        .foregroundStyle(Theme.hairline)
                        .annotation(position: .trailing, alignment: .center, spacing: 6) {
                            Text("\(row.flashes) flash · \(row.sends) send")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .glassEffect(.regular, in: .capsule)
                        }
                }
            }
            .chartForegroundStyleScale(["Flash": Theme.Chart.flash, "Send": Theme.Chart.send])
            .chartYScale(domain: rows.map { HexGrade(clamping: $0.grade).label }.reversed())
            .chartYSelection(value: $pyramidSelection)
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Theme.hairline)
                AxisValueLabel().foregroundStyle(Theme.inkTertiary)
            } }
            .chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(Theme.inkSecondary) } }
            .chartLegend(position: .top, alignment: .leading)
            .frame(height: CGFloat(rows.count) * 34 + 40)
        }
        .glassCard()
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
                            .glassEffect(.regular, in: .rect(cornerRadius: 10))
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
