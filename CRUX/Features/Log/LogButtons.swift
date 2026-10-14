import SwiftUI

/// The two big buttons: + Attempt, and Sent (tap logs the inferred type, long-press picks one).
struct LogButtons: View {
    let climb: Climb
    @Environment(LogCoordinator.self) private var logger

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    logger.log(.attempt, on: climb)
                } label: {
                    Label("Attempt", systemImage: "plus")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.glass)
                .accessibilityHint("Logs a try without sending")

                Menu {
                    Section("Log as") {
                        ForEach(SendType.allCases) { type in
                            Button(type.name, systemImage: type.symbol) {
                                logger.log(.send, on: climb, sendType: type)
                            }
                        }
                    }
                } label: {
                    Label(predicted.name, systemImage: predicted.symbol)
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 30)
                } primaryAction: {
                    logger.log(.send, on: climb)
                }
                .menuStyle(.button)
                .buttonStyle(.glassProminent)
                .tint(Theme.send)
                .accessibilityLabel("Log \(predicted.name.lowercased())")
                .accessibilityHint("Touch and hold to choose flash, send or repeat")
            }
            .controlSize(.large)
        }
    }

    /// What a plain tap on the send button will record.
    private var predicted: SendType {
        SendType.inferred(fromPrior: climb.chronologicalAttempts.map(\.outcome))
    }
}
