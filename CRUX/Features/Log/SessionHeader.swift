import SwiftUI

/// Live session status: a breathing "on the wall" pill, the clock, and today's totals.
struct SessionHeader: View {
    let session: ClimbSession?
    let onEnd: () -> Void

    @Environment(SessionConfig.self) private var config

    var body: some View {
        if let session {
            active(session)
        } else {
            idle
        }
    }

    private func active(_ session: ClimbSession) -> some View {
        let attempts = session.attempts ?? []
        let sends = attempts.filter(\.isSend)
        let flashes = sends.filter { $0.sendType == .flash }

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
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
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .glassEffect(.regular.tint(Theme.accent.opacity(0.14)), in: .capsule)
                .accessibilityElement(children: .combine)

                Spacer()

                Button("End", action: onEnd)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.glass)
                    .accessibilityLabel("End session")
            }

            HStack(spacing: 10) {
                StatTile(value: "\(attempts.count)", caption: "attempts", symbol: "hand.raised.fill")
                StatTile(value: "\(sends.count)", caption: "sends", tint: Theme.send, symbol: "checkmark")
                StatTile(value: "\(flashes.count)", caption: "flashes", tint: Theme.accent, symbol: "bolt.fill")
            }
            .animation(Theme.spring, value: attempts.count)
        }
    }

    private var idle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ready when you are")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("Tap + to start a session. It ends when you tap End, or after \(timeoutText) without a log.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .glassCard(padding: 18)
    }

    private var timeoutText: String { Format.timeout(config.effectiveTimeout) }
}
