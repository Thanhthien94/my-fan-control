import Foundation

public struct FanSchedule: Codable, Identifiable, Equatable, Sendable {
  public var id = UUID()
  public var name: String
  public var enabled = true
  public var fanIDs: [Int]
  public var preset: FanPreset
  public var durationMinutes: Int
  public var timing: Timing
  public enum Timing: Codable, Equatable, Sendable {
    case once(Date)
    /// Calendar weekday: Sunday=1 ... Saturday=7, in the current system timezone.
    case weekly(days: [Int], hour: Int, minute: Int)
  }
  public init(name: String, fanIDs: [Int], preset: FanPreset, durationMinutes: Int, timing: Timing)
  {
    self.name = name
    self.fanIDs = fanIDs
    self.preset = preset
    self.durationMinutes = durationMinutes
    self.timing = timing
  }
  public func validate() throws {
    try preset.validateDefinition()
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 100,
      !fanIDs.isEmpty, Set(fanIDs).count == fanIDs.count,
      fanIDs.allSatisfy({ (0..<10).contains($0) }),
      (1...1440).contains(durationMinutes), preset.mode != .automatic
    else {
      throw FanError.invalid(L10n.t("schedule.invalid"))
    }
    if case .weekly(let days, let hour, let minute) = timing {
      guard !days.isEmpty, Set(days).count == days.count, days.allSatisfy({ (1...7).contains($0) }),
        (0...23).contains(hour), (0...59).contains(minute)
      else {
        throw FanError.invalid(L10n.t("schedule.invalid"))
      }
    }
    if case .once(let date) = timing, !date.timeIntervalSince1970.isFinite {
      throw FanError.invalid(L10n.t("schedule.invalid"))
    }
  }
  public func nextFire(after date: Date, calendar: Calendar = .current) -> Date? {
    guard (try? validate()) != nil else { return nil }
    switch timing {
    case .once(let fire): return fire > date ? fire : nil
    case .weekly(let days, let hour, let minute):
      return days.compactMap { day in
        calendar.nextDate(
          after: date,
          matching: DateComponents(hour: hour, minute: minute, second: 0, weekday: day),
          matchingPolicy: .nextTime, repeatedTimePolicy: .first)
      }.min()
    }
  }
}

public enum SchedulePlanner {
  public static func conflicts(
    _ a: FanSchedule, _ b: FanSchedule, now: Date, calendar: Calendar = .current
  ) -> Bool {
    guard a.enabled, b.enabled, a.id != b.id, !Set(a.fanIDs).isDisjoint(with: b.fanIDs) else {
      return false
    }
    // Eight days cover weekly wrapping; center around a one-off date even if months away.
    let center: Date
    if case .once(let date) = a.timing {
      center = date
    } else if case .once(let date) = b.timing {
      center = date
    } else {
      center = now
    }
    let start = center.addingTimeInterval(-86400)
    let end = center.addingTimeInterval(8 * 86400)
    func intervals(_ schedule: FanSchedule) -> [DateInterval] {
      var cursor = start
      var values = [DateInterval]()
      for _ in 0..<16 {
        guard let fire = schedule.nextFire(after: cursor, calendar: calendar), fire <= end else {
          break
        }
        values.append(DateInterval(start: fire, duration: Double(schedule.durationMinutes) * 60))
        cursor = fire
      }
      return values
    }
    return intervals(a).contains { first in
      intervals(b).contains { second in first.start < second.end && second.start < first.end }
    }
  }
}
