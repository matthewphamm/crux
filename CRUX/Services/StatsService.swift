import Foundation

enum StatsRange: String, CaseIterable, Identifiable {
    case days30, days90, year, all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .days30: "30D"
        case .days90: "90D"
        case .year: "1Y"
        case .all: "All"
        }
    }

    func startDate(from now: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .days30: calendar.date(byAdding: .day, value: -30, to: now)
        case .days90: calendar.date(byAdding: .day, value: -90, to: now)
        case .year: calendar.date(byAdding: .year, value: -1, to: now)
        case .all: nil
        }
    }

    /// Bucket size for the sends-over-time chart.
    var bucket: Calendar.Component { self == .days30 || self == .days90 ? .weekOfYear : .month }
}

/// A climb's first send — the event every progress metric counts.
struct Top {
    let climbID: UUID
    let grade: Int
    let date: Date
    let tries: Int
    let flashed: Bool
}

struct PyramidRow: Identifiable, Equatable {
    let grade: Int
    let flashes: Int
    let sends: Int
    var id: Int { grade }
    var total: Int { flashes + sends }
}

struct GradeAverage: Identifiable, Equatable {
    let grade: Int
    let averageTries: Double
    let count: Int
    var id: Int { grade }
}

struct TimeBucket: Identifiable, Equatable {
    let start: Date
    let grade: Int
    let count: Int
    var id: String { "\(start.timeIntervalSince1970)-\(grade)" }
}

struct StyleStat: Identifiable, Equatable {
    let tag: StyleTag
    let tried: Int
    let sent: Int
    let highestSend: Int?
    var id: StyleTag { tag }
    var sendRate: Double { tried == 0 ? 0 : Double(sent) / Double(tried) }
}

struct Insight: Identifiable, Equatable {
    enum Kind { case weakness, strength }

    let kind: Kind
    let tag: StyleTag
    /// Grade floor the insight applies to ("at 4 Hex and above").
    let minGrade: Int
    let sent: Int
    let tried: Int
    let overallRate: Double

    var id: String { "\(tag.rawValue)-\(minGrade)-\(kind)" }
    var rate: Double { tried == 0 ? 0 : Double(sent) / Double(tried) }
    var gap: Double { abs(overallRate - rate) }

    var message: String {
        let scope = minGrade > 1 ? " at \(minGrade) Hex+" : ""
        let overall = Int((overallRate * 100).rounded())
        switch kind {
        case .weakness:
            return "You rarely send \(tag.name.lowercased())\(scope) — \(sent) of \(tried) sent, vs \(overall)% overall."
        case .strength:
            return "\(tag.name)\(scope) is a strength — \(sent) of \(tried) sent, vs \(overall)% overall."
        }
    }
}

struct WeekSummary: Equatable {
    let sessions: Int
    let sends: Int
    let hardestSend: Int?
}

struct SessionStats: Equatable {
    let duration: TimeInterval
    let attempts: Int
    let uniqueClimbs: Int
    let sends: Int
    let flashes: Int
    let hardestSend: Int?
    /// Attempts per send; nil when nothing was sent.
    let attemptsPerSend: Double?
    let pyramid: [PyramidRow]
}

/// Pure progress calculations over the model. No UI, no persistence — easy to test.
enum StatsService {
    static let currentGradeWindowDays = 60
    static let currentGradeMinimumSends = 3
    static let insightMinimumSample = 5
    static let insightGapThreshold = 0.25

    // MARK: Tops

    static func tops(from climbs: [Climb], since start: Date? = nil) -> [Top] {
        climbs.compactMap { climb -> Top? in
            let ordered = climb.chronologicalAttempts
            guard let index = ordered.firstIndex(where: \.isSend) else { return nil }
            let send = ordered[index]
            if let start, send.timestamp < start { return nil }
            return Top(
                climbID: climb.id,
                grade: climb.gradeValue,
                date: send.timestamp,
                tries: index + 1,
                flashed: send.sendType == .flash
            )
        }
    }

    static func pyramid(_ tops: [Top]) -> [PyramidRow] {
        HexGrade.allCases.map { grade in
            let atGrade = tops.filter { $0.grade == grade.rawValue }
            let flashes = atGrade.filter(\.flashed).count
            return PyramidRow(grade: grade.rawValue, flashes: flashes, sends: atGrade.count - flashes)
        }
    }

    static func flashRate(_ tops: [Top]) -> Double? {
        guard !tops.isEmpty else { return nil }
        return Double(tops.filter(\.flashed).count) / Double(tops.count)
    }

    static func averageTriesToSend(_ tops: [Top]) -> Double? {
        guard !tops.isEmpty else { return nil }
        return Double(tops.map(\.tries).reduce(0, +)) / Double(tops.count)
    }

    static func averageTriesByGrade(_ tops: [Top]) -> [GradeAverage] {
        Dictionary(grouping: tops, by: \.grade)
            .map { grade, group in
                GradeAverage(
                    grade: grade,
                    averageTries: Double(group.map(\.tries).reduce(0, +)) / Double(group.count),
                    count: group.count
                )
            }
            .sorted { $0.grade < $1.grade }
    }

    /// The highest grade with at least three sends in the last 60 days.
    static func currentGrade(from climbs: [Climb], now: Date, calendar: Calendar = .current) -> Int? {
        let start = calendar.date(byAdding: .day, value: -currentGradeWindowDays, to: now)
        let recent = tops(from: climbs, since: start)
        let counts = Dictionary(grouping: recent, by: \.grade).mapValues(\.count)
        return counts.filter { $0.value >= currentGradeMinimumSends }.keys.max()
    }

    static func maxGrade(_ tops: [Top]) -> Int? {
        tops.map(\.grade).max()
    }

    static func topsOverTime(_ tops: [Top], bucket: Calendar.Component, calendar: Calendar = .current) -> [TimeBucket] {
        var counts: [Date: [Int: Int]] = [:]
        for top in tops {
            guard let start = calendar.dateInterval(of: bucket, for: top.date)?.start else { continue }
            counts[start, default: [:]][top.grade, default: 0] += 1
        }
        return counts
            .flatMap { start, byGrade in byGrade.map { TimeBucket(start: start, grade: $0.key, count: $0.value) } }
            .sorted { ($0.start, $0.grade) < ($1.start, $1.grade) }
    }

    // MARK: Style

    /// Climbs with at least one log in the window.
    static func triedClimbs(_ climbs: [Climb], since start: Date?) -> [Climb] {
        climbs.filter { climb in
            (climb.attempts ?? []).contains { start == nil || $0.timestamp >= start! }
        }
    }

    static func styleBreakdown(_ climbs: [Climb], since start: Date? = nil) -> [StyleStat] {
        let tried = triedClimbs(climbs, since: start)
        return StyleTag.allCases.compactMap { tag in
            let tagged = tried.filter { $0.styleTags.contains(tag) }
            guard !tagged.isEmpty else { return nil }
            let sent = tagged.filter(\.hasSent)
            return StyleStat(tag: tag, tried: tagged.count, sent: sent.count, highestSend: sent.map(\.gradeValue).max())
        }
        .sorted { $0.tried > $1.tried }
    }

    /// Rule-based strengths and weaknesses: a tag whose send rate at a grade floor differs from your
    /// overall send rate at that floor by 25+ points, with at least five climbs behind it.
    static func insights(_ climbs: [Climb], since start: Date? = nil, limit: Int = 3) -> [Insight] {
        let tried = triedClimbs(climbs, since: start)
        var best: [StyleTag: Insight] = [:]

        for grade in HexGrade.allCases.map(\.rawValue) {
            let overall = tried.filter { $0.gradeValue >= grade }
            guard !overall.isEmpty else { continue }
            let overallRate = Double(overall.filter(\.hasSent).count) / Double(overall.count)

            for tag in StyleTag.allCases {
                let tagged = overall.filter { $0.styleTags.contains(tag) }
                guard tagged.count >= insightMinimumSample else { continue }
                let sent = tagged.filter(\.hasSent).count
                let rate = Double(sent) / Double(tagged.count)
                let delta = overallRate - rate
                guard abs(delta) >= insightGapThreshold else { continue }

                let candidate = Insight(
                    kind: delta > 0 ? .weakness : .strength,
                    tag: tag,
                    minGrade: grade,
                    sent: sent,
                    tried: tagged.count,
                    overallRate: overallRate
                )
                if let existing = best[tag], existing.gap >= candidate.gap { continue }
                best[tag] = candidate
            }
        }

        return best.values
            .sorted { ($0.kind == .weakness ? 0 : 1, -$0.gap) < ($1.kind == .weakness ? 0 : 1, -$1.gap) }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: Sessions

    static func sessionStats(_ session: ClimbSession, now: Date = .now) -> SessionStats {
        let attempts = session.chronologicalAttempts
        let sends = attempts.filter(\.isSend)
        let sendGrades = sends.compactMap { $0.climb?.gradeValue }
        let pyramid = HexGrade.allCases.map { grade in
            let atGrade = sends.filter { $0.climb?.gradeValue == grade.rawValue }
            let flashes = atGrade.filter { $0.sendType == .flash }.count
            return PyramidRow(grade: grade.rawValue, flashes: flashes, sends: atGrade.count - flashes)
        }
        return SessionStats(
            duration: session.duration(now: now),
            attempts: attempts.count,
            uniqueClimbs: Set(attempts.compactMap { $0.climb?.id }).count,
            sends: sends.count,
            flashes: sends.filter { $0.sendType == .flash }.count,
            hardestSend: sendGrades.max(),
            attemptsPerSend: sends.isEmpty ? nil : Double(attempts.count) / Double(sends.count),
            pyramid: pyramid
        )
    }

    /// Finished sessions in the calendar week containing `now`.
    static func weekSummary(_ sessions: [ClimbSession], now: Date, calendar: Calendar = .current) -> WeekSummary {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return WeekSummary(sessions: 0, sends: 0, hardestSend: nil)
        }
        let thisWeek = sessions.filter { !$0.isOpen && week.contains($0.startedAt) && !($0.attempts ?? []).isEmpty }
        let sends = thisWeek.flatMap { ($0.attempts ?? []).filter(\.isSend) }
        return WeekSummary(
            sessions: thisWeek.count,
            sends: sends.count,
            hardestSend: sends.compactMap { $0.climb?.gradeValue }.max()
        )
    }

    /// "+3 sends vs your last 5 sessions", comparing against the sessions just before this one.
    static func comparison(for session: ClimbSession, among sessions: [ClimbSession], window: Int = 5) -> String? {
        let previous = sessions
            .filter { $0.id != session.id && $0.startedAt < session.startedAt && !$0.isOpen }
            .sorted { $0.startedAt > $1.startedAt }
            .prefix(window)
        guard !previous.isEmpty else { return nil }

        let average = Double(previous.map { ($0.attempts ?? []).filter(\.isSend).count }.reduce(0, +)) / Double(previous.count)
        let sends = (session.attempts ?? []).filter(\.isSend).count
        let delta = Int((Double(sends) - average).rounded())
        let label = previous.count == 1 ? "your last session" : "your last \(previous.count) sessions"
        switch delta {
        case 0: return "Right on your average for \(label)"
        case let d where d > 0: return "+\(d) \(d == 1 ? "send" : "sends") vs \(label)"
        default: return "\(delta) \(delta == -1 ? "send" : "sends") vs \(label)"
        }
    }
}
