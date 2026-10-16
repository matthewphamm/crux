import SwiftUI

/// + Attempt and Send on a climb's page. Send shows the inferred type; touch and hold to pick another.
/// Logging here starts a session if none is running.
struct LogButtons: View {
    let climb: Climb
    @Environment(LogCoordinator.self) private var logger

    var body: some View {
        HStack(spacing: 10) {
            Button {
                logger.log(.attempt, on: climb)
            } label: {
                Label("Attempt", systemImage: "plus")
            }
            .buttonStyle(ControlButtonStyle(ink: Theme.accent))
            .accessibilityHint("Logs a try without sending")

            Button {
                logger.log(.send, on: climb)
            } label: {
                Label(predicted.name, systemImage: predicted.symbol)
            }
            .buttonStyle(AccentButtonStyle(fill: Theme.send, ink: Theme.onSend))
            .contextMenu {
                Section("Log as") {
                    ForEach(SendType.allCases) { type in
                        Button(type.name, systemImage: type.symbol) {
                            logger.log(.send, on: climb, sendType: type)
                        }
                    }
                }
            }
            .accessibilityLabel("Log \(predicted.name.lowercased())")
            .accessibilityHint("Touch and hold to choose flash, send or repeat")
        }
    }

    /// What a plain tap on the send button will record.
    private var predicted: SendType {
        SendType.inferred(fromPrior: climb.chronologicalAttempts.map(\.outcome))
    }
}
