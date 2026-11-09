import Foundation
import Testing

@testable import FanCore

struct ReleaseFoundationTests {
  @Test func versionComparisonHandlesNumericAndPreviewOrder() throws {
    #expect(try AppVersion("0.10.0") > AppVersion("0.9.9"))
    #expect(try AppVersion("0.3.0") > AppVersion("0.3.0-preview.9"))
    #expect(try AppVersion("0.3.0-preview.10") > AppVersion("0.3.0-preview.2"))
    #expect(throws: (any Error).self) { try AppVersion("garbage") }
  }
  @Test func backupRoundTripIsVersionedAndDisablesImportedSchedules() throws {
    let preset = FanPreset(name: "Work", mode: .fixed, rpm: 2000)
    let schedule = FanSchedule(name: "Morning", fanIDs: [0], preset: preset,
      durationMinutes: 10, timing: .weekly(days: [2], hour: 9, minute: 0))
    let data = try ConfigurationBackup(presets: [preset], schedules: [schedule]).encoded()
    let restored = try ConfigurationBackup.decode(data)
    #expect(restored.presets == [preset])
    let plan = try restored.merge(presets: [preset], schedules: [])
    #expect(plan.presets.count == 1)
    #expect(plan.schedules.count == 1 && !plan.schedules[0].enabled)
    #expect(plan.schedules[0].id != schedule.id)
  }
  @Test func backupConflictsPreserveExistingPresets() throws {
    let existing = FanPreset(name: "Work", mode: .fixed, rpm: 2000)
    var changed = existing
    changed.rpm = 2500
    let plan = try ConfigurationBackup(presets: [changed], schedules: []).merge(
      presets: [existing], schedules: [])
    #expect(plan.presets[0] == existing)
    #expect(plan.presets.count == 2 && plan.presets[1].id != existing.id)
    #expect(plan.presets[1].name != existing.name)
  }
  @Test func badBackupNeverPartiallyImports() throws {
    let valid = FanPreset(name: "Work", mode: .fixed, rpm: 2000)
    let invalid = FanPreset(name: "Broken", mode: .sensor, sensor: "Tp01", start: 1e100, full: 75)
    #expect(throws: (any Error).self) {
      try ConfigurationBackup(presets: [valid, invalid], schedules: []).merge(presets: [], schedules: [])
    }
    #expect(throws: (any Error).self) { try ConfigurationBackup.decode(Data(repeating: 32, count: 1_048_577)) }
  }
  @Test func displayUnitAndCSVAreConsistent() throws {
    #expect(TemperatureUnit.fahrenheit.value(0) == 32)
    #expect(TemperatureUnit.fahrenheit.value(100) == 212)
    let snapshot = Snapshot(fans: [], sensors: [Sensor(id: "Tp01", name: "CPU, \"fast\"", celsius: 50)])
    let csv = SensorCSV.export(snapshot, unit: .fahrenheit)
    #expect(csv.contains("122.0") && csv.contains("°F"))
    #expect(csv.contains("\"CPU, \"\"fast\"\"\""))
  }
}
