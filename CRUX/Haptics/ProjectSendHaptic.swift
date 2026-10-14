import CoreHaptics

/// The reward for finishing a project: three rising taps, then a warm swell that softens as it fades.
enum ProjectSendHaptic {
    static func pattern() throws -> CHHapticPattern {
        let taps: [(time: TimeInterval, intensity: Float, sharpness: Float)] = [
            (0.00, 0.4, 0.45),
            (0.09, 0.7, 0.55),
            (0.18, 1.0, 0.65),
        ]
        var events = taps.map { tap in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: tap.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: tap.sharpness),
                ],
                relativeTime: tap.time
            )
        }

        let swellStart: TimeInterval = 0.27
        let swellDuration: TimeInterval = 0.35
        events.append(
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4),
                ],
                relativeTime: swellStart,
                duration: swellDuration
            )
        )

        let intensity = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0, value: 0.35),
                .init(relativeTime: 0.12, value: 1.0),
                .init(relativeTime: swellDuration, value: 0.0),
            ],
            relativeTime: swellStart
        )
        let sharpness = CHHapticParameterCurve(
            parameterID: .hapticSharpnessControl,
            controlPoints: [
                .init(relativeTime: 0, value: 0.2),
                .init(relativeTime: swellDuration, value: -0.3),
            ],
            relativeTime: swellStart
        )

        return try CHHapticPattern(events: events, parameterCurves: [intensity, sharpness])
    }
}
