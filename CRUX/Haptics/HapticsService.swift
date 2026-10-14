import CoreHaptics
import SwiftUI
import UIKit

/// Plays the custom Core Haptics moments. Everyday taps use SwiftUI's `.sensoryFeedback` via `cruxFeedback`.
final class HapticsService {
    static let shared = HapticsService()
    static let enabledKey = "haptics.enabled"

    private var engine: CHHapticEngine?
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    /// Warms the engine so the first pattern plays without delay.
    func prepare() {
        guard supportsHaptics, engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            engine.resetHandler = { [weak engine] in try? engine?.start() }
            try engine.start()
            self.engine = engine
        } catch {
            engine = nil
        }
    }

    func playProjectSend() {
        guard isEnabled else { return }
        prepare()
        do {
            guard let engine else { throw CocoaError(.featureUnsupported) }
            try engine.start()
            let player = try engine.makePlayer(with: ProjectSendHaptic.pattern())
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

extension View {
    /// `.sensoryFeedback` that respects the Haptics setting.
    func cruxFeedback<T: Equatable>(_ feedback: SensoryFeedback, trigger: T) -> some View {
        modifier(CruxFeedback(trigger: trigger) { _, _ in feedback })
    }

    func cruxFeedback<T: Equatable>(trigger: T, _ feedback: @escaping (T, T) -> SensoryFeedback?) -> some View {
        modifier(CruxFeedback(trigger: trigger, feedback: feedback))
    }
}

private struct CruxFeedback<T: Equatable>: ViewModifier {
    @AppStorage(HapticsService.enabledKey) private var enabled = true
    let trigger: T
    let feedback: (T, T) -> SensoryFeedback?

    func body(content: Content) -> some View {
        content.sensoryFeedback(trigger: trigger) { old, new in
            enabled ? feedback(old, new) : nil
        }
    }
}
