import SwiftUI

/// A climb on the Quick log screen: who it is, how it's going this session, and the log buttons.
struct ClimbLogCard: View {
    let climb: Climb
    let session: ClimbSession?
    let namespace: Namespace.ID

    @Environment(LogCoordinator.self) private var logger

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NavigationLink(value: climb) {
                HStack(spacing: 14) {
                    HexBadge(
                        grade: climb.grade,
                        color: climb.holdColor,
                        size: 48,
                        glowing: climb.status.isTopped,
                        bloom: logger.bloom[climb.id] ?? 0
                    )
                    .matchedTransitionSource(id: climb.id, in: namespace)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(climb.displayName)
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSecondary)
                            .lineLimit(1)
                        StatusLabel(status: climb.status)
                            .padding(.top, 1)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(sessionTries)")
                            .font(.number(.title2))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText(value: Double(sessionTries)))
                        Text(sessionTries == 1 ? "try today" : "tries today")
                            .font(.caption2)
                            .foregroundStyle(Theme.inkTertiary)
                    }
                    .accessibilityElement(children: .combine)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            LogButtons(climb: climb)
        }
        .glassCard(tint: climb.status.isTopped ? Theme.send : nil)
        .animation(Theme.spring, value: climb.status)
    }

    private var sessionTries: Int {
        session.map { climb.tries(in: $0) } ?? 0
    }

    private var subtitle: String {
        [climb.grade.vRange, climb.wall?.name].compactMap(\.self).joined(separator: " · ")
    }
}
