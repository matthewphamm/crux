import Foundation
import Observation
import SwiftUI

/// Shared logging front-end: performs logs, then drives the toast, undo, haptics and project bloom
/// so every screen that logs (Quick log, climb detail) feels identical.
@Observable
final class LogCoordinator {
    private let sessions: SessionManager

    private(set) var toast: Toast?
    /// Reverts exactly what the current toast describes.
    private var undoAction: (() -> Void)?

    // Feedback triggers, observed by `.logFeedback()` at the root.
    private(set) var attemptTick = 0
    private(set) var sendTick = 0
    private(set) var flashTick = 0
    private(set) var undoTick = 0

    /// Incremented per climb to play the HexBadge glow bloom.
    private(set) var bloom: [UUID: Int] = [:]

    /// Drives the full-screen live session (the + button in the tab bar).
    var isSessionPresented = false
    private(set) var startTick = 0

    init(sessions: SessionManager) {
        self.sessions = sessions
    }

    /// Starts a session if none is running, then shows it.
    func openSession() {
        if sessions.activeSession == nil {
            withAnimation(Theme.spring) { sessions.startSession() }
            startTick += 1
        }
        isSessionPresented = true
    }

    func log(_ outcome: AttemptOutcome, on climb: Climb, sendType: SendType? = nil) {
        let result = withAnimation(Theme.spring) {
            sessions.log(outcome, on: climb, sendType: sendType)
        }
        let undo = { [sessions] in sessions.undo(result) }

        switch (outcome, result.sendType) {
        case (.attempt, _):
            attemptTick += 1
            let tries = result.attempt.session.map { climb.tries(in: $0) } ?? climb.tryCount
            show(Toast(message: "\(climb.displayName) · try \(tries) logged", symbol: "plus", tint: Theme.accent), undo: undo)
        case (.send, _) where result.completedProject:
            HapticsService.shared.playProjectSend()
            bloom[climb.id, default: 0] += 1
            show(Toast(message: "Project sent! \(climb.displayName)", symbol: "sparkles", tint: Theme.accent), undo: undo)
        case (.send, .flash):
            flashTick += 1
            bloom[climb.id, default: 0] += 1
            show(Toast(message: "Flashed! \(climb.displayName)", symbol: "bolt.fill", tint: Theme.accent), undo: undo)
        case (.send, let type):
            sendTick += 1
            let verb = type == .repeat ? "Repeated" : "Sent"
            show(Toast(message: "\(verb) \(climb.displayName)", symbol: "checkmark", tint: Theme.send), undo: undo)
        }
    }

    func undo() {
        guard let undoAction else { return }
        withAnimation(Theme.spring) {
            undoAction()
            toast = nil
        }
        self.undoAction = nil
        undoTick += 1
    }

    func dismissToast(_ id: UUID) {
        guard toast?.id == id else { return }
        withAnimation(.smooth) { toast = nil }
        undoAction = nil
    }

    /// Shows a toast. With `undo`, the toast offers Undo that runs it.
    func show(_ toast: Toast, undo: (() -> Void)? = nil) {
        var toast = toast
        toast.undo = undo != nil
        undoAction = undo
        withAnimation(Theme.spring) { self.toast = toast }
    }
}

extension View {
    /// Everyday haptics for logging, attached once at the root.
    func logFeedback(_ logger: LogCoordinator) -> some View {
        self
            .cruxFeedback(.impact(weight: .medium), trigger: logger.startTick)
            .cruxFeedback(.impact(weight: .light), trigger: logger.attemptTick)
            .cruxFeedback(.success, trigger: logger.sendTick)
            .cruxFeedback(.impact(weight: .medium), trigger: logger.flashTick)
            .modifier(DelayedSuccess(trigger: logger.flashTick))
            .cruxFeedback(.selection, trigger: logger.undoTick)
    }

    /// Shows the log toast above the bottom edge, auto-dismissing after four seconds.
    func logToast() -> some View {
        modifier(LogToastHost())
    }
}

/// Flash = a medium tap followed shortly by a success notification.
private struct DelayedSuccess: ViewModifier {
    let trigger: Int
    @State private var echo = 0

    func body(content: Content) -> some View {
        content
            .cruxFeedback(.success, trigger: echo)
            .onChange(of: trigger) {
                Task {
                    try? await Task.sleep(for: .milliseconds(140))
                    echo += 1
                }
            }
    }
}

private struct LogToastHost: ViewModifier {
    @Environment(LogCoordinator.self) private var logger

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 8) {
                if let toast = logger.toast {
                    ToastView(toast: toast) { logger.undo() }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: toast.id) {
                            try? await Task.sleep(for: .seconds(4))
                            logger.dismissToast(toast.id)
                        }
                }
            }
    }
}
