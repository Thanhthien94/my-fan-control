import FanCore
import Foundation
import Testing

@testable import MyFanControl

@MainActor struct PresetDeletionTests {
  @Test func deletingAnActivePresetRestoresEveryFanUsingItsIDAndPersistsDeletion() async throws {
    let (store, hardware, _, defaults) = ScheduleExecutionTests().fixture(.now)
    var preset = FanPreset(name: "Work", mode: .fixed, rpm: 2500)
    store.save(preset)
    #expect(await store.activate(preset, fanIDs: [0, 1]))
    // Editing the saved definition must not break identity matching with the running copy.
    preset.rpm = 3000
    store.save(preset)
    await store.deletePreset(preset.id)
    #expect(await hardware.ids().isEmpty)
    #expect(store.active.isEmpty && store.controlled.isEmpty)
    #expect(store.presets.isEmpty && store.error == nil)
    let reopened = FanStore(hardware: hardware, defaults: defaults, observeSleep: false)
    #expect(reopened.presets.isEmpty)
  }
  @Test func deletingOnePresetDoesNotRestoreFansUsingAnotherPreset() async {
    let (store, hardware, _, _) = ScheduleExecutionTests().fixture(.now)
    let first = FanPreset(name: "First", mode: .fixed, rpm: 2500)
    let second = FanPreset(name: "Second", mode: .fixed, rpm: 3000)
    store.save(first); store.save(second)
    #expect(await store.activate(first, fanIDs: [0]))
    #expect(await store.activate(second, fanIDs: [1]))
    await store.deletePreset(first.id)
    #expect(await hardware.ids() == [1])
    #expect(store.active[1] == second && store.presets == [second])
  }
  @Test func failedRestoreKeepsPresetAndErrorThenDeletionCanBeRetried() async {
    let (store, hardware, _, defaults) = ScheduleExecutionTests().fixture(.now)
    let preset = FanPreset(name: "Work", mode: .fixed, rpm: 2500)
    store.save(preset)
    #expect(await store.activate(preset, fanIDs: [0, 1]))
    await hardware.failOneRestore()
    await store.deletePreset(preset.id)
    #expect(store.presets == [preset] && store.error != nil)
    #expect(store.operationMessage == nil)
    #expect(await hardware.ids() == [0])
    #expect(FanStore(hardware: hardware, defaults: defaults, observeSleep: false).presets == [preset])
    await store.deletePreset(preset.id)
    #expect(await hardware.ids().isEmpty)
    #expect(store.presets.isEmpty && store.error == nil)
  }
  @Test func deletingAnUnusedPresetDoesNotAuthorizeOrAlterRunningFans() async {
    let (store, hardware, _, _) = ScheduleExecutionTests().fixture(.now)
    let unused = FanPreset(name: "Unused", mode: .fixed, rpm: 2500)
    let running = FanPreset(name: "Running", mode: .fixed, rpm: 3000)
    store.save(unused); store.save(running)
    #expect(await store.activate(running, fanIDs: [0]))
    let count = await hardware.configurationCount()
    await store.deletePreset(unused.id)
    #expect(await hardware.ids() == [0])
    #expect(await hardware.configurationCount() == count)
    #expect(await hardware.authorizations() == 0)
  }
  @Test func busyDeletionDoesNotRemoveThePreset() async {
    let (store, _, _, _) = ScheduleExecutionTests().fixture(.now)
    let preset = FanPreset(name: "Work", mode: .fixed, rpm: 2500)
    store.save(preset)
    store.busy = true
    await store.deletePreset(preset.id)
    #expect(store.presets == [preset])
  }
  @Test func deletingScheduledActivePresetEndsCurrentRunButPreservesFutureScheduleDefinition() async throws {
    let base = Date()
    let (store, hardware, schedules, defaults) = ScheduleExecutionTests().fixture(base)
    let preset = FanPreset(name: "Work", mode: .fixed, rpm: 2500)
    store.save(preset)
    let job = FanSchedule(name: "Cooling", fanIDs: [0, 1], preset: preset,
      durationMinutes: 10, timing: .once(base.addingTimeInterval(1)))
    try schedules.save(job)
    await schedules.tick(store: store, now: base.addingTimeInterval(2))
    #expect(schedules.running.count == 1)
    await store.deletePreset(preset.id)
    #expect(await hardware.ids().isEmpty && schedules.running.isEmpty)
    #expect(schedules.items[0].preset == preset)
    #expect(ScheduleStore(defaults: defaults).items[0].preset == preset)
  }
}
