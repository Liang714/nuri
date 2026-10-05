import Foundation
import Testing
@testable import NuriDomain

@Suite struct CalendarDayTests {
    func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    @Test func seoulPastMidnightIsNextDay() {
        let d = CalendarDay(date: date("2026-10-05T15:30:00Z"), timeZone: TimeZone(identifier: "Asia/Seoul")!)
        #expect(d.description == "2026-10-06")
    }

    @Test func newYorkAcrossDSTStart() {
        let ny = TimeZone(identifier: "America/New_York")!
        // 23:30 EST on 2026-03-07 (before DST)
        #expect(CalendarDay(date: date("2026-03-08T04:30:00Z"), timeZone: ny).description == "2026-03-07")
        // 23:30 EDT on 2026-03-08 (DST day)
        #expect(CalendarDay(date: date("2026-03-09T03:30:00Z"), timeZone: ny).description == "2026-03-08")
    }

    @Test func ordering() {
        #expect(CalendarDay(year: 2026, month: 1, day: 31) < CalendarDay(year: 2026, month: 2, day: 1))
    }

    @Test func daysRemainingInWeek() {
        let monday = CalendarDay(year: 2026, month: 10, day: 5)
        #expect(monday.daysRemainingInWeek(firstWeekday: 2) == 7) // week starts Monday
        #expect(monday.daysRemainingInWeek(firstWeekday: 1) == 6) // week starts Sunday
        let sunday = CalendarDay(year: 2026, month: 10, day: 11)
        #expect(sunday.daysRemainingInWeek(firstWeekday: 2) == 1)
    }
}
