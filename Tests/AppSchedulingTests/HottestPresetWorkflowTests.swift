import FanCore
import Foundation
import Testing

@testable import MyFanControl

@MainActor struct HottestPresetWorkflowTests {
  @Test func savesRelaunchesAndActivatesForOneOrAllFans() async throws {
    for ids in [[0], [0, 1]] {
      let (store, hardware, _, defaults) = ScheduleExecutionTests().fixture(.now)
      let rule = FanPreset(name: "Hottest", mode: .sensor, sensor: "auto:hottest")
      #expect(store.save(rule) == rule)
      let reopened = FanStore(hardware: hardware, defaults: defaults, observeSleep: false)
      #expect(reopened.presets == [rule])
      #expect(await reopened.activate(rule, fanIDs: ids))
      #expect(await hardware.ids() == Set(ids))
      #expect(reopened.operationMessage?.contains("auto:hottest") == false)
      #expect(!rule.summary.contains("auto:hottest"))
    }
  }
  @Test func scheduledHottestPresetStartsAndReturnsToAutomatic() async throws {
    let base = Date()
    let instant = ContinuousClock.now
    let (store, hardware, schedules, _) = ScheduleExecutionTests().fixture(base)
    let rule = FanPreset(name: "Hottest", mode: .sensor, sensor: "auto:hottest")
    let job = FanSchedule(name: "Cooling", fanIDs: [0, 1], preset: rule,
      durationMinutes: 1, timing: .once(base.addingTimeInterval(1)))
    try schedules.save(job)
    await schedules.tick(store: store, now: base.addingTimeInterval(2), instant: instant)
    #expect(await hardware.ids() == [0, 1])
    #expect(store.active[0]?.sensor == "auto:hottest")
    await schedules.tick(store: store, now: base.addingTimeInterval(62),
      instant: instant.advanced(by: .seconds(60)))
    #expect(await hardware.ids().isEmpty)
  }
}
