#if DEBUG
import Foundation
import SwiftData

/// Generates ~10 weeks of believable climbing history for development and screenshots.
/// The sample climber is progressing from mid-3 to mid-4 Hex, loves overhangs and avoids slab.
enum SeedData {
    static func loadSample(into gym: Gym, context: ModelContext, now: Date = .now) {
        wipe(gym, context: context)
        var rng = SeededGenerator(seed: 383)
        let calendar = Calendar.current

        // (name, tags, days ago the current set went up — nil means it predates the sample window)
        let wallSpecs: [(String, [StyleTag], Int?)] = [
            ("Cave", [.overhang, .roof, .jugs, .compression, .dyno], 38),
            ("Slab", [.slab, .technical, .crimpy, .mantle], 9),
            ("Overhang", [.overhang, .pinchy, .compression, .slopey], nil),
            ("Comp wall", [.coordination, .dyno, .vertical, .slopey], 24),
        ]

        let start = calendar.date(byAdding: .day, value: -70, to: now)!

        var available: [(climb: Climb, from: Date, until: Date?)] = []

        for (index, spec) in wallSpecs.enumerated() {
            let wall = Wall(name: spec.0, sortOrder: index)
            context.insert(wall)
            wall.gym = gym

            let resetDate = spec.2.flatMap { calendar.date(byAdding: .day, value: -$0, to: now) }
            let batches: [(Date, Date?)] = resetDate.map { [(start, $0), ($0, nil)] } ?? [(start, nil)]
            for (from, until) in batches {
                for _ in 0..<9 {
                    let climb = makeClimb(tags: spec.1, created: from, rng: &rng)
                    context.insert(climb)
                    climb.wall = wall
                    climb.strippedAt = until
                    available.append((climb, from, until))
                }
            }
            if let resetDate {
                let reset = WallReset(date: resetDate, note: spec.0 == "Comp wall" ? "Comp set" : "", strippedCount: 9)
                context.insert(reset)
                reset.wall = wall
                wall.lastResetAt = resetDate
            } else {
                wall.lastResetAt = start
            }
        }

        // Roughly three sessions a week, ending yesterday.
        var day = start
        while day < calendar.startOfDay(for: now) {
            defer { day = calendar.date(byAdding: .day, value: Int.random(in: 2...3, using: &rng), to: day)! }
            let progress = day.timeIntervalSince(start) / now.timeIntervalSince(start)
            let level = 3.4 + progress * 1.2
            let sessionStart = calendar.date(bySettingHour: 18, minute: Int.random(in: 0...45, using: &rng), second: 0, of: day)!

            let session = ClimbSession(startedAt: sessionStart)
            context.insert(session)
            session.gym = gym

            let pool = available.filter { $0.from <= day && ($0.until.map { day < $0 } ?? true) }.map(\.climb)
            let picks = pool.shuffled(using: &rng).prefix(Int.random(in: 6...10, using: &rng))

            var clock = sessionStart
            for climb in picks where !climb.hasSent || Double.random(in: 0...1, using: &rng) < 0.15 {
                let tries = Int.random(in: 1...4, using: &rng)
                for _ in 0..<tries {
                    clock = clock.addingTimeInterval(Double.random(in: 120...420, using: &rng))
                    let prior = climb.chronologicalAttempts.map(\.outcome)
                    let sent = Double.random(in: 0...1, using: &rng) < sendChance(climb, level: level, priorTries: prior.count)
                    let attempt = Attempt(
                        timestamp: clock,
                        outcome: sent ? .send : .attempt,
                        sendType: sent ? SendType.inferred(fromPrior: prior) : nil
                    )
                    context.insert(attempt)
                    attempt.climb = climb
                    attempt.session = session
                    if sent { break }
                }
            }
            session.endedAt = clock.addingTimeInterval(300)
        }

        // A few things to look forward to.
        let unsent = available.map(\.climb).filter { $0.isActive && !$0.hasSent }
        for climb in unsent.prefix(3) { climb.isProjectFlagged = true }
        unsent.dropFirst(4).first?.isProjectFlagged = true

        try? context.save()
    }

    static func wipe(_ gym: Gym, context: ModelContext) {
        for session in gym.sessions ?? [] { context.delete(session) }
        for wall in gym.walls ?? [] {
            for climb in wall.climbs ?? [] { context.delete(climb) }
            context.delete(wall)
        }
        try? context.save()
    }

    private static func makeClimb(tags: [StyleTag], created: Date, rng: inout SeededGenerator) -> Climb {
        let pool = [1, 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 5, 5, 5, 6]
        let grade = HexGrade(clamping: pool.randomElement(using: &rng)!)
        let color = HoldColor.allCases.randomElement(using: &rng)!
        let chosen = Set(tags.shuffled(using: &rng).prefix(Int.random(in: 1...2, using: &rng)))
        return Climb(grade: grade, holdColor: color, styleTags: chosen, createdAt: created)
    }

    private static func sendChance(_ climb: Climb, level: Double, priorTries: Int) -> Double {
        var chance = 0.3 + (level - Double(climb.gradeValue)) * 0.22 + Double(min(priorTries, 4)) * 0.06
        if climb.styleTags.contains(.slab) { chance -= 0.3 }
        if climb.styleTags.contains(.overhang) { chance += 0.12 }
        return min(max(chance, 0.02), 0.95)
    }
}

/// Deterministic RNG so sample data looks the same every time.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
#endif
