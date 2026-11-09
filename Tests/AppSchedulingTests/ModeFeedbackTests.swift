import FanCore
import Foundation
import Testing

@testable import MyFanControl

@MainActor struct ModeFeedbackTests {
  @Test func automaticSuccessDoesNotUseThePreviousManualPresetName() async {
    let (store, _, _, _) = ScheduleExecutionTests().fixture(.now)
    let preset = FanPreset(name: "RPM fixed", mode: .fixed, rpm: 2000)
    store.save(preset)
    #expect(await store.activate(preset, fanIDs: [0, 1]))
    var automatic = preset
    automatic.mode = .automatic
    #expect(await store.activate(automatic, fanIDs: [0, 1]))
    #expect(store.operationMessage == L10n.t("preset.alreadyAuto"))
    #expect(store.presets == [preset])
  }
  @Test func manualSuccessIsClearedWhenControlReturnsWithoutANotice() async {
    let (store, hardware, _, _) = ScheduleExecutionTests().fixture(.now)
    #expect(await store.activate(FanPreset(name: "Work", mode: .fixed, rpm: 2000), fanIDs: [0]))
    #expect(store.operationMessage != nil)
    await hardware.handBackAll()
    await store.refresh()
    #expect(store.active.isEmpty && store.fans.allSatisfy { !$0.manual })
    #expect(store.operationMessage == nil)
  }
  @Test func successExpiresWithoutChangingFanControl() async {
    let (_, hardware, _, defaults) = ScheduleExecutionTests().fixture(.now)
    var instant = ContinuousClock.now
    let store = FanStore(hardware: hardware, defaults: defaults, observeSleep: false, feedbackNow: { instant })
    #expect(await store.activate(FanPreset(name: "Work", mode: .fixed, rpm: 2000), fanIDs: [0]))
    #expect(store.operationMessage != nil)
    instant = instant.advanced(by: .seconds(7))
    await store.refresh()
    #expect(store.operationMessage == nil && store.active[0] != nil)
  }
  @Test func failedAutomaticRequestNeverShowsSuccess() async {
    let (store, hardware, _, _) = ScheduleExecutionTests().fixture(.now)
    let preset = FanPreset(name: "Work", mode: .fixed, rpm: 2000)
    #expect(await store.activate(preset, fanIDs: [0]))
    await hardware.failOneRestore()
    var automatic = preset
    automatic.mode = .automatic
    #expect(!(await store.activate(automatic, fanIDs: [0])))
    #expect(store.error != nil && store.operationMessage == nil)
  }

}
