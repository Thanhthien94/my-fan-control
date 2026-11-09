import FanCore
import Foundation
import Testing

@testable import MyFanControl

@MainActor struct PresetWorkflowTests {
  @Test func asynchronousHelperStartupFailureIsVisibleWithoutWaitingForTimeout() async {
    let (store, hardware, _, _) = ScheduleExecutionTests().fixture(Date())
    store.helperEnabled = false
    await hardware.requireAuthorization(failure: "Hardware startup failed")
    #expect(!(await store.activate(FanPreset(name: "Work", mode: .fixed, rpm: 2500), fanIDs: [0])))
    #expect(store.error == "Hardware startup failed")
    #expect(await hardware.configurationCount() == 0)
  }
  @Test func obsoleteHelperProtocolIsUpgradedBeforeApplyingAPreset() async {
    let (store, hardware, _, _) = ScheduleExecutionTests().fixture(Date())
    store.helperEnabled = false
    await hardware.useOldProtocol()
    #expect(await store.activate(FanPreset(name: "Work", mode: .fixed, rpm: 2500), fanIDs: [0]))
    #expect(await hardware.authorizations() == 1)
  }
  @Test func savingChangesUpdatesTheSamePresetAndSurvivesRelaunch() {
    let (store, hardware, _, defaults) = ScheduleExecutionTests().fixture(Date())
    var preset = FanPreset(name: "Work", mode: .fixed, rpm: 2500)
    store.save(preset)
    preset.rpm = 3000
    store.save(preset)
    #expect(store.presets.count == 1)
    #expect(store.presets.first == preset)
    let reopened = FanStore(hardware: hardware, defaults: defaults, observeSleep: false)
    #expect(reopened.presets == [preset])
  }
  @Test func pollingDoesNotEraseAnActionFailure() async {
    let (store, hardware, _, _) = ScheduleExecutionTests().fixture(Date())
    await hardware.fail(on: 0)
    #expect(!(await store.apply(FanPreset(name: "Work", mode: .fixed, rpm: 2500), to: 0)))
    let failure = store.error
    #expect(failure != nil)
    await store.refresh()
    #expect(store.error == failure)
  }
  @Test func applyingSavedPresetAuthorizesAndKeepsItsIdentity() async {
    let (store, hardware, _, defaults) = ScheduleExecutionTests().fixture(Date())
    let original = FanPreset(name: "Saved Work", mode: .fixed, rpm: 2500)
    store.save(original)
    let reopened = FanStore(hardware: hardware, defaults: defaults, observeSleep: false)
    await hardware.requireAuthorization()
    let selected = reopened.presets[0]
    #expect(await reopened.activate(selected, fanIDs: [0, 1]))
    #expect(await hardware.authorizations() == 1)
    #expect(reopened.active[0] == original && reopened.active[1] == original)
    await reopened.refresh()
    #expect(reopened.active[0]?.id == original.id)
    #expect(reopened.operationMessage != nil)
  }
  @Test func cancelingAuthorizationNeverAppliesOrErasesTheSavedPreset() async {
    let (store, hardware, _, _) = ScheduleExecutionTests().fixture(Date())
    let preset = FanPreset(name: "Work", mode: .fixed, rpm: 2500)
    store.save(preset)
    store.helperEnabled = false
    await hardware.requireAuthorization(cancel: true)
    #expect(!(await store.activate(preset, fanIDs: [0])))
    #expect(await hardware.configurationCount() == 0)
    #expect(await hardware.ids().isEmpty)
    #expect(store.presets == [preset])
    let error = store.error
    await store.refresh()
    #expect(store.error == error && error != nil)
  }
  @Test func rejectedSavePreservesExistingSettings() {
    let (store, _, _, _) = ScheduleExecutionTests().fixture(Date())
    let preset = FanPreset(name: "Work", mode: .fixed, rpm: 2500)
    store.save(preset)
    #expect(store.save(FanPreset(name: "  ", mode: .fixed, rpm: 3000)) == nil)
    #expect(store.save(FanPreset(name: "Work", mode: .fixed, rpm: 3000)) == nil)
    #expect(store.presets == [preset])
  }
}
