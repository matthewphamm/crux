import SwiftData
import SwiftUI

/// "Session complete": the hardest send as the hero, the numbers, how it compares, and every climb.
/// Shown as a full-screen cover after ending a session, or pushed from history.
struct SessionSummaryView: View {
    let session: ClimbSession
    /// Covers get a Done button; pushes use the navigation back button.
    var isCover = true

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ClimbSession.startedAt, order: .reverse) private var allSessions: [ClimbSession]
    @State private var viewing: BetaMedia?
    @State private var appeared = false

    var body: some View {
        if isCover {
            NavigationStack {
                content
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { dismiss() }
                                .buttonStyle(PillButtonStyle(filled: true))
                        }
                    }
                    .navigationDestination(for: Climb.self) { ClimbDetailView(climb: $0) }
            }
            .cruxFeedback(.success, trigger: appeared)
            .onAppear { appeared = true }
        } else {
            content
        }
    }

    private var content: some View {
        let stats = StatsService.sessionStats(session)
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                header(stats)
                hero
                tiles(stats)
                if let comparison = StatsService.sendComparison(for: session, among: allSessions) {
                    comparisonCard(stats, comparison)
                }
                climbsList
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.bottom, 32)
        }
        .background {
            ZStack {
                NightGymBackground()
                RadialGradient(
                    colors: [Theme.send.opacity(0.16), .clear],
                    center: UnitPoint(x: 0.5, y: 0), startRadius: 0, endRadius: 420
                )
                .ignoresSafeArea()
            }
        }
        .scrollContentBackground(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $viewing) { MediaViewer(media: $0) }
    }

    // MARK: Header & hero

    private func header(_ stats: SessionStats) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "Session complete", color: Theme.send)
            Text([
                session.startedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                Format.duration(stats.duration),
                session.gym?.name,
            ].compactMap(\.self).joined(separator: " · "))
                .font(.system(size: 15))
                .foregroundStyle(Theme.inkSecondary)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var hero: some View {
        if let climb = heroClimb {
            VStack(spacing: 12) {
                HexBadge(grade: climb.grade, color: climb.holdColor, size: 96, glowing: true)
                    .padding(.bottom, 4)
                Text(heroTitle(climb))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text(heroSubtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    /// The hardest send, or the most-tried climb when nothing was sent.
    private var heroSend: Attempt? {
        (session.attempts ?? [])
            .filter(\.isSend)
            .max { ($0.climb?.gradeValue ?? 0, -$0.timestamp.timeIntervalSince1970) < ($1.climb?.gradeValue ?? 0, -$1.timestamp.timeIntervalSince1970) }
    }

    private var heroClimb: Climb? {
        if let climb = heroSend?.climb { return climb }
        let counts = Dictionary(grouping: (session.attempts ?? []).compactMap(\.climb), by: \.id)
        return counts.values.max { $0.count < $1.count }?.first
    }

    private func heroTitle(_ climb: Climb) -> String {
        heroSend == nil ? climb.displayName : "Sent \(climb.displayName)"
    }

    private var heroSubtitle: String {
        guard let send = heroSend, let climb = send.climb else {
            return "No sends this time. Most tried climb."
        }
        switch send.sendType {
        case .flash: return "Hardest send · flashed"
        case .repeat: return "Hardest send · repeat"
        default: return "Hardest send · in \(Format.tries(tries(on: climb, upTo: send)))"
        }
    }

    // MARK: Tiles & comparison

    private func tiles(_ stats: SessionStats) -> some View {
        HStack(spacing: Theme.Spacing.cardGap) {
            StatTile(value: "\(stats.attempts)", caption: "tries")
            StatTile(value: "\(stats.sends)", caption: "sends", tint: Theme.send, tintsValue: true)
            StatTile(value: Format.decimal(stats.attemptsPerSend), caption: "tries / send")
        }
    }

    private func comparisonCard(_ stats: SessionStats, _ comparison: (delta: Int, average: Double, count: Int)) -> some View {
        let rows = stats.pyramid.filter { $0.total > 0 }.sorted { $0.grade > $1.grade }
        let peak = max(rows.map(\.total).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 14) {
            if !rows.isEmpty {
                VStack(spacing: 5) {
                    ForEach(rows) { row in
                        HStack(spacing: 10) {
                            Text("\(row.grade)")
                                .font(.number(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.inkTertiary)
                                .frame(width: 14)
                            Capsule()
                                .fill(HexGrade(clamping: row.grade).tint)
                                .frame(width: max(12, 180 * CGFloat(row.total) / CGFloat(peak)), height: 10)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                (Text(deltaText(comparison.delta)).font(.system(size: 17, weight: .bold)).foregroundStyle(comparison.delta >= 0 ? Theme.send : Theme.ink)
                    + Text(" vs your last \(comparison.count == 1 ? "session" : "\(comparison.count) sessions")")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.ink))
                Text("Average \(Format.decimal(comparison.average)) sends per session")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .glassCard(padding: 18, radius: 24)
    }

    private func deltaText(_ delta: Int) -> String {
        switch delta {
        case 0: "Same sends"
        case let d where d > 0: "+\(d) \(d == 1 ? "send" : "sends")"
        default: "\(delta) \(delta == -1 ? "send" : "sends")"
        }
    }

    // MARK: Climbs

    private var climbsList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
            SectionHeader(title: "Climbs", trailing: "\(climbs.count)")
            VStack(spacing: 8) {
                ForEach(climbs) { climb in
                    NavigationLink(value: climb) {
                        climbRow(climb)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func climbRow(_ climb: Climb) -> some View {
        let media = (session.attempts ?? [])
            .filter { $0.climb?.id == climb.id }
            .flatMap { $0.media ?? [] }
            .sorted { $0.createdAt < $1.createdAt }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                HexBadge(grade: climb.grade, color: climb.holdColor, size: 38, glowing: outcome(climb).sent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(climb.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(outcome(climb).text)
                        .font(.system(size: 13, weight: outcome(climb).sent ? .semibold : .regular))
                        .foregroundStyle(outcome(climb).sent ? Theme.send : Theme.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkTertiary)
            }
            if !media.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(media) { item in
                            Button { viewing = item } label: { MediaThumbnail(media: item, size: 56) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .glassCard(padding: 14, tint: outcome(climb).sent ? Theme.send : nil)
    }

    /// Climbs in the order you first tried them.
    private var climbs: [Climb] {
        session.chronologicalAttempts.compactMap(\.climb).uniqued()
    }

    private func outcome(_ climb: Climb) -> (text: String, sent: Bool) {
        let tries = session.chronologicalAttempts.filter { $0.climb?.id == climb.id }
        guard let send = tries.first(where: \.isSend) else { return (Format.tries(tries.count), false) }
        switch send.sendType {
        case .flash: return ("Flash · \(Format.tries(tries.count))", true)
        case .repeat: return ("Repeat · \(Format.tries(tries.count))", true)
        default: return ("Sent · \(Format.tries(tries.count))", true)
        }
    }

    private func tries(on climb: Climb, upTo send: Attempt) -> Int {
        session.chronologicalAttempts.filter { $0.climb?.id == climb.id && $0.timestamp <= send.timestamp }.count
    }
}
