import Charts
import SwiftUI

/// Session history with a volume sparkline.
struct SessionsListView: View {
    let sessions: [ClimbSession]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                if sessions.count > 1 { sparkline }
                LazyVStack(spacing: 10) {
                    ForEach(sessions) { session in
                        NavigationLink(value: session) { SessionRow(session: session) }
                            .buttonStyle(.plain)
                    }
                }
                if sessions.isEmpty {
                    ContentUnavailableView("No sessions yet", systemImage: "calendar",
                                           description: Text("Sessions appear here once they wrap up."))
                }
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.bottom, 24)
        }
        .nightGymBackground()
        .navigationTitle("Sessions")
    }

    private var sparkline: some View {
        let recent = Array(sessions.prefix(20).reversed())
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Volume", trailing: "last \(recent.count) sessions")
            Chart(recent) { session in
                AreaMark(x: .value("Date", session.startedAt), y: .value("Attempts", session.attempts?.count ?? 0))
                    .foregroundStyle(LinearGradient(colors: [Theme.Chart.send.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Date", session.startedAt), y: .value("Attempts", session.attempts?.count ?? 0))
                    .foregroundStyle(Theme.Chart.send)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden)
            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 2)) { _ in
                AxisGridLine().foregroundStyle(Theme.hairline)
                AxisValueLabel().foregroundStyle(Theme.inkTertiary)
            } }
            .frame(height: 80)
            .accessibilityLabel("Attempts per session over your last \(recent.count) sessions")
        }
        .glassCard()
    }
}

struct SessionRow: View {
    let session: ClimbSession
    /// Hardest-send badge on the right. Hidden on Home to keep it calm.
    var showsHardest = true

    var body: some View {
        let stats = StatsService.sessionStats(session)
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.startedAt.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("\(Format.duration(stats.duration)) · \(Format.count(stats.attempts, "attempt")) · \(Format.count(stats.sends, "send"))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            if showsHardest, let hardest = stats.hardestSend {
                HexBadge(grade: HexGrade(clamping: hardest), color: .black, size: 34, glowing: true)
                    .accessibilityLabel("Hardest send \(HexGrade(clamping: hardest).label)")
            }
        }
        .glassCard(padding: 14)
        .accessibilityElement(children: .combine)
    }
}
