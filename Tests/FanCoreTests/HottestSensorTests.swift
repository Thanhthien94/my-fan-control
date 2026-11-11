import Foundation
import Testing

@testable import FanCore

private final class HottestHardware: FanHardware {
  var fans = [
    Fan(id: 0, name: "Left", current: 2000, minimum: 1000, maximum: 6000),
    Fan(id: 1, name: "Right", current: 2000, minimum: 1500, maximum: 5500),
  ]
  var sensors = [Sensor(id: "Tp01", name: "CPU", celsius: 60),
    Sensor(id: "Tg01", name: "GPU", celsius: 50)]
  var writes: [Int: Double] = [:]
  var writeCount = 0
  var restores = Set<Int>()
  func snapshot() -> Snapshot { Snapshot(fans: fans, sensors: sensors) }
  func setTarget(fan: Fan, rpm: Double) { writes[fan.id] = rpm; writeCount += 1 }
  func restore(_ id: Int) { restores.insert(id) }
}

struct HottestSensorTests {
  private let rule = FanPreset(
    name: "Hottest", mode: .sensor, sensor: "auto:hottest", start: 40, full: 80)
  @Test func selectionSurvivesPresetScheduleAndBackupRoundTrip() throws {
    try rule.validateDefinition()
    let job = FanSchedule(name: "Cooling", fanIDs: [0, 1], preset: rule,
      durationMinutes: 10, timing: .weekly(days: [2], hour: 9, minute: 0))
    let decoded = try ConfigurationBackup.decode(
      ConfigurationBackup(presets: [rule], schedules: [job]).encoded())
    #expect(decoded.presets == [rule])
    #expect(decoded.schedules[0].preset == rule)
    let imported = try decoded.merge(presets: [], schedules: [])
    #expect(imported.schedules[0].preset.sensor == "auto:hottest")
    #expect(!imported.schedules[0].enabled)
  }
  @Test func eachHelperSampleCanSwitchToANewHottestSensor() throws {
    let hw = HottestHardware()
    let session = ControlSession(hardware: hw)
    try session.configure(id: 0, rule: rule)
    #expect(hw.writes[0] == 3500)
    hw.sensors[1].celsius = 70
    session.tick(leaseAge: 1)
    #expect(hw.writes[0] == 4750)
    // Catalog visibility does not exclude a valid, hotter unidentified channel.
    hw.sensors = [Sensor(id: "ZZZZ", name: "Unknown", celsius: 80)]
    session.tick(leaseAge: 1)
    #expect(hw.writes[0] == 6000)
    #expect(hw.restores.isEmpty)
  }
  @Test func groupUsesHottestSampleWithEachFansOwnLimits() throws {
    let hw = HottestHardware()
    let session = ControlSession(hardware: hw)
    try session.configureGroup(ids: [0, 1], rule: rule)
    #expect(hw.writes[0] == 3500 && hw.writes[1] == 3500)
    hw.sensors[1].celsius = 80
    session.tick(leaseAge: 1)
    #expect(hw.writes[0] == 6000 && hw.writes[1] == 5500)
  }
  @Test func disappearanceOfPreviousWinnerSelectsRemainingFreshSensor() throws {
    let hw = HottestHardware()
    let session = ControlSession(hardware: hw)
    try session.configure(id: 0, rule: rule)
    hw.sensors.removeFirst()
    session.tick(leaseAge: 1)
    #expect(hw.writes[0] == 2250 && session.activeIDs == [0])
  }
  @Test func missingInvalidHotOrExpiredSamplesRestoreBothFans() throws {
    for fault in 0..<4 {
      let hw = HottestHardware()
      let session = ControlSession(hardware: hw)
      try session.configureGroup(ids: [0, 1], rule: rule)
      if fault == 0 { hw.sensors = [] }
      if fault == 1 { hw.sensors[0].celsius = .nan }
      if fault == 2 { hw.sensors[0].celsius = 90 }
      session.tick(leaseAge: fault == 3 ? 10 : 1)
      #expect(hw.writeCount == 2)
      #expect(hw.restores == [0, 1] && session.owned.isEmpty)
    }
  }
  @Test func legacyExplicitSensorStaysPinnedAndStillRestoresOnItsLoss() throws {
    let hw = HottestHardware()
    var pinned = rule
    pinned.sensor = "Tg01"
    let decoded = try JSONDecoder().decode(FanPreset.self, from: JSONEncoder().encode(pinned))
    try decoded.validateDefinition()
    let session = ControlSession(hardware: hw)
    try session.configure(id: 0, rule: decoded)
    #expect(hw.writes[0] == 2250)
    hw.sensors.removeLast()
    session.tick(leaseAge: 1)
    #expect(hw.restores == [0])
  }
  @Test func arbitrarySelectorsAndEmptySelectionRemainInvalid() {
    for value in ["", "auto:unknown", "auto:hottest "] {
      var bad = rule
      bad.sensor = value
      #expect(throws: (any Error).self) { try bad.validateDefinition() }
    }
  }
}
