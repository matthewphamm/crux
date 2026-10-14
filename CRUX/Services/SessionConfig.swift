import Foundation
import Observation

/// How long a session may sit idle before it closes itself.
///
/// In DEBUG builds a developer override shortens the timeout so auto-close can be tested in seconds.
/// The override is compiled out of Release builds entirely.
@Observable
final class SessionConfig {
    static let defaultTimeoutMinutes = 90
    static let timeoutRange = 30...180

    private let defaults: UserDefaults

    var timeoutMinutes: Int {
        didSet { defaults.set(timeoutMinutes, forKey: Keys.timeout) }
    }

    #if DEBUG
    enum DebugTimeout: String, CaseIterable, Identifiable {
        case off, thirtySeconds, twoMinutes, fiveMinutes

        var id: String { rawValue }

        var seconds: TimeInterval? {
            switch self {
            case .off: nil
            case .thirtySeconds: 30
            case .twoMinutes: 120
            case .fiveMinutes: 300
            }
        }

        var label: String {
            switch self {
            case .off: "Off"
            case .thirtySeconds: "30 sec"
            case .twoMinutes: "2 min"
            case .fiveMinutes: "5 min"
            }
        }
    }

    var debugTimeout: DebugTimeout {
        didSet { defaults.set(debugTimeout.rawValue, forKey: Keys.debugTimeout) }
    }
    #endif

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.integer(forKey: Keys.timeout)
        self.timeoutMinutes = Self.timeoutRange.contains(stored) ? stored : Self.defaultTimeoutMinutes
        #if DEBUG
        self.debugTimeout = DebugTimeout(rawValue: defaults.string(forKey: Keys.debugTimeout) ?? "") ?? .off
        #endif
    }

    /// The timeout actually applied, in seconds.
    var effectiveTimeout: TimeInterval {
        #if DEBUG
        if let seconds = debugTimeout.seconds { return seconds }
        #endif
        return TimeInterval(timeoutMinutes * 60)
    }

    private enum Keys {
        static let timeout = "session.timeoutMinutes"
        static let debugTimeout = "session.debugTimeout"
    }
}
