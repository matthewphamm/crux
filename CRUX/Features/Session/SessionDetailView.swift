import Charts
import SwiftData
import SwiftUI

/// A session's story: totals, its mini pyramid, how it compares, and a timeline with beta clips.
/// Also used as the summary sheet when you end a session.
struct SessionDetailView: View {
    let session: ClimbSession
    var isSummary = false

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ClimbSession.startedAt, order: .reverse) private var allSessions: [ClimbSession]
    @State private var viewing: BetaMedia?
    @State private var appeared = false

    var body: some View {
        if isSummary {
            NavigationStack { content.toolbar { doneButton } }
                .presentationDetents([.large])
                .cruxFeedback(.success, trigger: appeared)
        } else {
            content
        }
    }

    private var content: some View {
        let stats = StatsService.sessionStats(session)
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                header(stats)
                tiles(stats)
                if stats.sends > 0 { miniPyramid(stats) }
                timeline
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.bottom, 24)
        }
        .nightGymBackground()
        .navigationTitle(isSummary ? "Session wrapped" : session.startedAt.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $viewing) { MediaViewer(media: $0) }
        .onAppear { appeared = true }
    }

    private var doneButton: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done", systemImage: "checkmark") { dismiss() }
                .buttonStyle(.glassProminent)
        }
    }

    private func header(_ stats: SessionStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.startedAt.formatted(.dateTime.weekday(.wide).month().day().hour().minute()))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
            Text(Format.duration(stats.duration))
                .font(.number(.largeTitle, weight: .bold))
                .foregroundStyle(Theme.ink)
            if let comparison = StatsService.comparison(for: session, among: allSessions) {
                Label(comparison, systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.top, 8)
    }

    private func tiles(_ stats: SessionStats) -> some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                StatTile(value: "\(stats.attempts)", caption: "attempts", symbol: "hand.raised.fill")
                StatTile(value: "\(stats.uniqueClimbs)", caption: "climbs", symbol: "hexagon")
                StatTile(value: "\(stats.sends)", caption: "sends", tint: Theme.send, symbol: "checkmark")
            }
            GridRow {
                StatTile(value: "\(stats.flashes)", caption: "flashes", tint: Theme.accent, symbol: "bolt.fill")
                StatTile(value: stats.hardestSend.map { "\($0) Hex" } ?? "—", caption: "hardest send")
                StatTile(value: Format.decimal(stats.attemptsPerSend), caption: "tries / send")
            }
        }
    }

    private func miniPyramid(_ stats: SessionStats) -> some View {
        let rows = stats.pyramid.filter { $0.total > 0 }
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Sends by grade")
            Chart {
                ForEach(rows) { row in
                    BarMark(x: .value("Count", row.flashes), y: .value("Grade", HexGrade(clamping: row.grade).label))
                        .foregroundStyle(by: .value("Type", "Flash"))
                        .cornerRadius(4)
                    BarMark(x: .value("Count", row.sends), y: .value("Grade", HexGrade(clamping: row.grade).label))
                        .foregroundStyle(by: .value("Type", "Send"))
                        .cornerRadius(4)
                }
            }
            .chartForegroundStyleScale(["Flash": Theme.Chart.flash, "Send": Theme.Chart.send])
            .chartYScale(domain: rows.map { HexGrade(clamping: $0.grade).label }.reversed())
            .chartXAxis(.hidden)
            .chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(Theme.inkSecondary) } }
            .chartLegend(position: .top, alignment: .leading)
            .frame(height: CGFloat(rows.count) * 30 + 36)
        }
        .glassCard()
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
            SectionHeader(title: "Timeline")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(session.chronologicalAttempts) { attempt in
                    HStack(alignment: .top, spacing: 12) {
                        Text(attempt.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.number(.caption, weight: .regular))
                            .foregroundStyle(Theme.inkTertiary)
                            .frame(width: 64, alignment: .leading)
                            .padding(.top, 8)
                        if let climb = attempt.climb {
                            HexBadge(grade: climb.grade, color: climb.holdColor, size: 28, glowing: attempt.isSend)
                                .padding(.top, 2)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(attempt.climb?.displayName ?? "Deleted climb")
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink)
                            Label(attempt.sendType?.name ?? "Attempt", systemImage: attempt.sendType?.symbol ?? "circle")
                                .font(.caption)
                                .foregroundStyle(attempt.isSend ? Theme.send : Theme.inkTertiary)
                            let media = (attempt.media ?? []).sorted { $0.createdAt < $1.createdAt }
                            if !media.isEmpty {
                                HStack(spacing: 6) {
                                    ForEach(media) { item in
                                        Button { viewing = item } label: { MediaThumbnail(media: item, size: 64) }
                                            .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                }
            }
            .glassCard()
        }
    }
}
