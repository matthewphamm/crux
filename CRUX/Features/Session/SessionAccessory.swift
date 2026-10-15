import SwiftUI

/// The bar that rides on the tab bar: "+ Start session", or the running session's clock.
/// Tapping it opens the live session.
struct SessionAccessory: View {
    @Environment(SessionManager.self) private var sessions
    @Environment(LogCoordinator.self) private var logger
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        Button {
            logger.openSession()
        } label: {
            if let session = sessions.activeSession {
                active(session)
            } else {
                idle
            }
        }
        .buttonStyle(.plain)
        .animation(Theme.spring, value: sessions.activeSession?.id)
    }

    private var idle: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.accent)
            Text("Start session")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
            if placement != .inline {
                Text("Log your climbs")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
        .padding(.horizontal, 18)
        .frame(maxHeight: .infinity)
        .contentShape(.rect)
        .accessibilityLabel("Start session")
        .accessibilityHint("Starts a session and opens it to log your climbs")
    }

    private func active(_ session: ClimbSession) -> some View {
        let attempts = session.attempts?.count ?? 0
        return HStack(spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(Theme.accent)
                .symbolEffect(.breathe.pulse, options: .repeat(.continuous))
            TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                Text(Format.clock(context.date.timeIntervalSince(session.startedAt)))
                    .font(.number(.subheadline))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
            }
            Text("in session")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
            Spacer(minLength: 0)
            if placement != .inline {
                Text(attempts == 1 ? "1 log" : "\(attempts) logs")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.inkSecondary)
                    .contentTransition(.numericText(value: Double(attempts)))
            }
            Image(systemName: "chevron.up")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.inkTertiary)
        }
        .padding(.horizontal, 18)
        .frame(maxHeight: .infinity)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Session in progress, \(attempts) logs")
        .accessibilityHint("Opens your session")
    }
}
