import Foundation
import Testing

@testable import FanCore

struct ScheduleTests {
  let preset = FanPreset(name: "Cooling", mode: .fixed, rpm: 2500)
  func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
  var utc: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(secondsFromGMT: 0)!
    return c
  }
  @Test func onceIsStrictlyFutureAndDoesNotRepeat() throws {
    let fire = date("2026-11-09T10:00:00Z")
    let schedule = FanSchedule(
      name: "Once", fanIDs: [0], preset: preset, durationMinutes: 30, timing: .once(fire))
    #expect(schedule.nextFire(after: fire.addingTimeInterval(-1), calendar: utc) == fire)
    #expect(schedule.nextFire(after: fire, calendar: utc) == nil)
    #expect(schedule.nextFire(after: fire.addingTimeInterval(1), calendar: utc) == nil)
  }
  @Test func weeklyRollsToNextSelectedWeekday() {
    let schedule = FanSchedule(
      name: "Weekly", fanIDs: [0], preset: preset, durationMinutes: 30,
      timing: .weekly(days: [2, 4], hour: 10, minute: 0))
    #expect(
      schedule.nextFire(after: date("2026-11-09T09:00:00Z"), calendar: utc)
        == date("2026-11-09T10:00:00Z"))
    #expect(
      schedule.nextFire(after: date("2026-11-09T10:00:00Z"), calendar: utc)
        == date("2026-11-11T10:00:00Z"))
  }
  @Test func overlapsUseFanOwnershipAndAllowAdjacentIntervals() {
    let now = date("2026-11-09T09:00:00Z")
    let fire = date("2026-11-09T10:00:00Z")
    let a = FanSchedule(
      name: "A", fanIDs: [0], preset: preset, durationMinutes: 30, timing: .once(fire))
    var b = FanSchedule(
      name: "B", fanIDs: [0], preset: preset, durationMinutes: 30,
      timing: .once(fire.addingTimeInterval(60)))
    #expect(SchedulePlanner.conflicts(a, b, now: now, calendar: utc))
    b.fanIDs = [1]
    #expect(!SchedulePlanner.conflicts(a, b, now: now, calendar: utc))
    b.fanIDs = [0]
    b.timing = .once(fire.addingTimeInterval(1800))
    #expect(!SchedulePlanner.conflicts(a, b, now: now, calendar: utc))
  }
  @Test func distantOneOffConflictsWithWeeklyAndWrapsMidnight() {
    let now = date("2026-11-09T09:00:00Z")
    let weekly = FanSchedule(
      name: "Weekly", fanIDs: [0], preset: preset, durationMinutes: 120,
      timing: .weekly(days: [2], hour: 23, minute: 30))
    let once = FanSchedule(
      name: "Once", fanIDs: [0], preset: preset, durationMinutes: 30,
      timing: .once(date("2027-01-05T00:00:00Z")))
    #expect(SchedulePlanner.conflicts(weekly, once, now: now, calendar: utc))
  }
  @Test func invalidPersistedSchedulesDoNotProduceDates() {
    var bad = FanSchedule(
      name: "Bad", fanIDs: [0], preset: preset, durationMinutes: 0,
      timing: .weekly(days: [9], hour: 25, minute: -1))
    #expect(throws: (any Error).self) { try bad.validate() }
    #expect(bad.nextFire(after: date("2026-11-09T00:00:00Z")) == nil)
    bad.durationMinutes = 10
    bad.timing = .weekly(days: [2], hour: 10, minute: 0)
    bad.fanIDs = [0, 0]
    #expect(throws: (any Error).self) { try bad.validate() }
  }
  @Test func springDSTGapResolvesToARealLocalTime() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    let schedule = FanSchedule(
      name: "DST", fanIDs: [0], preset: preset, durationMinutes: 30,
      timing: .weekly(days: [1], hour: 2, minute: 30))
    let fire = schedule.nextFire(after: date("2027-03-14T08:00:00Z"), calendar: calendar)!
    let fields = calendar.dateComponents([.year, .month, .day, .hour], from: fire)
    #expect(fields.day == 14)
    #expect(fields.hour == 3)
  }
}
