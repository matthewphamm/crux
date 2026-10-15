import Foundation
import Testing
@testable import CRUX

@Suite("Progress stats")
@MainActor
struct StatsServiceTests {
    @Test func pyramidSplitsFlashesFromSends() {
        let env = TestEnvironment()
        env.work(env.climb(.three), failures: 0, thenSend: true) // flash
        env.work(env.climb(.three), failures: 2, thenSend: true) // send
        env.work(env.climb(.four), failures: 1, thenSend: true)  // send
        env.work(env.climb(.five), failures: 3, thenSend: false) // not a top

        let climbs = env.wall.climbs ?? []
        let tops = StatsService.tops(from: climbs)
        let pyramid = StatsService.pyramid(tops)

        #expect(tops.count == 3)
        #expect(pyramid.first { $0.grade == 3 } == PyramidRow(grade: 3, flashes: 1, sends: 1))
        #expect(pyramid.first { $0.grade == 4 } == PyramidRow(grade: 4, flashes: 0, sends: 1))
        #expect(pyramid.first { $0.grade == 5 }?.total == 0)
        #expect(StatsService.maxGrade(tops) == 4)
    }

    @Test func repeatsDoNotCountAsNewTops() {
        let env = TestEnvironment()
        let climb = env.climb()
        env.work(climb, failures: 0, thenSend: true)
        env.work(climb, failures: 0, thenSend: true)
        #expect(StatsService.tops(from: [climb]).count == 1)
    }

    @Test func flashRateAndAverageTries() {
        let env = TestEnvironment()
        env.work(env.climb(.three), failures: 0, thenSend: true) // 1 try, flash
        env.work(env.climb(.three), failures: 2, thenSend: true) // 3 tries
        env.work(env.climb(.four), failures: 4, thenSend: true)  // 5 tries
        let tops = StatsService.tops(from: env.wall.climbs ?? [])

        #expect(StatsService.flashRate(tops) == 1.0 / 3.0)
        #expect(StatsService.averageTriesToSend(tops) == 3)
        let byGrade = StatsService.averageTriesByGrade(tops)
        #expect(byGrade == [
            GradeAverage(grade: 3, averageTries: 2, count: 2),
            GradeAverage(grade: 4, averageTries: 5, count: 1),
        ])
    }

    @Test func emptyDataHasNoRates() {
        #expect(StatsService.flashRate([]) == nil)
        #expect(StatsService.averageTriesToSend([]) == nil)
    }

    @Test func currentGradeNeedsThreeRecentSends() {
        let env = TestEnvironment()
        for _ in 0..<3 { env.work(env.climb(.four), failures: 1, thenSend: true) }
        for _ in 0..<2 { env.work(env.climb(.five), failures: 1, thenSend: true) }
        let climbs = env.wall.climbs ?? []
        #expect(StatsService.currentGrade(from: climbs, now: env.clock.now) == 4)

        // Two months later, those sends have aged out.
        let later = Calendar.current.date(byAdding: .day, value: 61, to: env.clock.now)!
        #expect(StatsService.currentGrade(from: climbs, now: later) == nil)
    }

    @Test func rangeFilterExcludesOlderTops() {
        let env = TestEnvironment()
        let old = env.climb()
        env.work(old, failures: 0, thenSend: true)
        env.clock.advance(minutes: 60 * 24 * 40)
        env.work(env.climb(), failures: 0, thenSend: true)

        let start = StatsRange.days30.startDate(from: env.clock.now)
        #expect(StatsService.tops(from: env.wall.climbs ?? [], since: start).count == 1)
    }

    @Test func sessionStatsRatioAndHardest() {
        let env = TestEnvironment()
        env.work(env.climb(.three), failures: 2, thenSend: true)
        env.work(env.climb(.five), failures: 3, thenSend: true)
        env.work(env.climb(.four), failures: 0, thenSend: true)
        let session = try! #require(env.sessions.activeSession)

        let stats = StatsService.sessionStats(session, now: env.clock.now)
        #expect(stats.attempts == 8)
        #expect(stats.sends == 3)
        #expect(stats.flashes == 1)
        #expect(stats.uniqueClimbs == 3)
        #expect(stats.hardestSend == 5)
        #expect(stats.attemptsPerSend == 8.0 / 3.0)
    }

    @Test func sessionComparisonAgainstRecentAverage() {
        let env = TestEnvironment(timeoutMinutes: 30)
        // Two earlier sessions with 1 send each.
        for _ in 0..<2 {
            env.work(env.climb(), failures: 0, thenSend: true)
            env.clock.advance(minutes: 60)
        }
        // This session: 4 sends.
        for _ in 0..<4 { env.work(env.climb(), failures: 0, thenSend: true) }
        let current = try! #require(env.sessions.endActiveSession())

        #expect(StatsService.comparison(for: current, among: env.allSessions()) == "+3 sends vs your last 2 sessions")
    }

    @Test func weekSummaryCountsOnlyThisWeek() throws {
        let env = TestEnvironment(timeoutMinutes: 30)
        // Last week: a session that shouldn't count.
        env.clock.now = Calendar.current.date(byAdding: .day, value: -8, to: env.clock.now)!
        env.work(env.climb(.six), failures: 0, thenSend: true)
        env.sessions.endActiveSession()
        // This week: two sessions.
        env.clock.now = Date(timeIntervalSince1970: 1_790_000_000)
        let week = Calendar.current.dateInterval(of: .weekOfYear, for: env.clock.now)!
        env.clock.now = week.start.addingTimeInterval(3600)
        env.work(env.climb(.three), failures: 1, thenSend: true)
        env.sessions.endActiveSession()
        env.clock.advance(minutes: 120)
        env.work(env.climb(.four), failures: 0, thenSend: true)
        env.work(env.climb(.two), failures: 2, thenSend: false)
        env.sessions.endActiveSession()

        let summary = StatsService.weekSummary(env.allSessions(), now: env.clock.now)
        #expect(summary == WeekSummary(sessions: 2, sends: 2, hardestSend: 4))
    }

    @Test func insightFlagsAWeakStyle() {
        let env = TestEnvironment()
        // Slab: 1 of 6 sent.
        for index in 0..<6 { env.work(env.climb(.four, tags: [.slab]), failures: 2, thenSend: index == 0) }
        // Overhang: 6 of 6 sent.
        for _ in 0..<6 { env.work(env.climb(.four, tags: [.overhang]), failures: 1, thenSend: true) }

        let insights = StatsService.insights(env.wall.climbs ?? [])
        let slab = try! #require(insights.first { $0.tag == .slab })
        #expect(slab.kind == .weakness)
        #expect(slab.sent == 1 && slab.tried == 6)
        #expect(slab.message.contains("rarely send slab"))
        #expect(insights.first?.kind == .weakness)
        #expect(insights.contains { $0.tag == .overhang && $0.kind == .strength })
    }

    @Test func insightStaysQuietWithSmallSamples() {
        let env = TestEnvironment()
        for _ in 0..<4 { env.work(env.climb(.four, tags: [.slab]), failures: 2, thenSend: false) }
        for _ in 0..<6 { env.work(env.climb(.four, tags: [.overhang]), failures: 1, thenSend: true) }

        let insights = StatsService.insights(env.wall.climbs ?? [])
        #expect(!insights.contains { $0.tag == .slab })
    }

    @Test func styleBreakdownCountsTriedAndSent() {
        let env = TestEnvironment()
        env.work(env.climb(.three, tags: [.crimpy]), failures: 1, thenSend: true)
        env.work(env.climb(.five, tags: [.crimpy]), failures: 2, thenSend: false)

        let crimpy = try! #require(StatsService.styleBreakdown(env.wall.climbs ?? []).first { $0.tag == .crimpy })
        #expect(crimpy.tried == 2)
        #expect(crimpy.sent == 1)
        #expect(crimpy.highestSend == 3)
        #expect(crimpy.sendRate == 0.5)
    }
}

@Suite("Climb filters")
@MainActor
struct ClimbFilterTests {
    @Test func segmentsAndFilters() {
        let env = TestEnvironment()
        let tick = env.climb(.three, tags: [.slab])
        let project = env.climb(.five, tags: [.overhang])
        project.isProjectFlagged = true
        let stripped = env.climb(.two)
        stripped.strippedAt = env.clock.now
        let climbs = [tick, project, stripped]

        #expect(ClimbFilter.apply(climbs, segment: .projects, filter: .init(), sort: .grade) == [project])
        #expect(ClimbFilter.apply(climbs, segment: .stripped, filter: .init(), sort: .grade) == [stripped])
        #expect(ClimbFilter.apply(climbs, segment: .all, filter: .init(), sort: .grade) == [project, tick])

        var filter = ClimbFilter()
        filter.grades = [.four, .five]
        #expect(ClimbFilter.apply(climbs, segment: .all, filter: filter, sort: .grade) == [project])

        filter = ClimbFilter()
        filter.tags = [.slab]
        #expect(ClimbFilter.apply(climbs, segment: .all, filter: filter, sort: .grade) == [tick])
        #expect(filter.isActive)
    }
}

@Suite("Session calendar")
struct CalendarMonthTests {
    @Test func padsLeadingDaysToTheFirstWeekday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Vancouver")!
        calendar.firstWeekday = 1 // Sunday
        // October 2026 starts on a Thursday.
        let october = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 15)))
        let days = CalendarMonth.days(in: october, calendar: calendar)

        #expect(days.prefix(4).allSatisfy { $0 == nil })
        #expect(days.compactMap(\.self).count == 31)
        #expect(days[4].map { calendar.component(.day, from: $0) } == 1)

        calendar.firstWeekday = 2 // Monday
        #expect(CalendarMonth.days(in: october, calendar: calendar).prefix(while: { $0 == nil }).count == 3)
        #expect(CalendarMonth.weekdaySymbols(calendar: calendar).first == "M")
    }
}
