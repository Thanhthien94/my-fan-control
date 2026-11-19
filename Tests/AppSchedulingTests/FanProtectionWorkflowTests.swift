import FanCore
import Foundation
import Testing
@testable import MyFanControl

@MainActor struct FanProtectionWorkflowTests {
  @Test func enabledByDefaultAndPersistsTheChosenToggleThroughRelaunchAndActivation() async {
    let (store, hw, _, defaults) = ScheduleExecutionTests().fixture(.now)
    #expect(store.fanProtectionEnabled)
    #expect(await store.setFanProtection(false))
    let reopened = FanStore(hardware: hw, defaults: defaults, observeSleep: false)
    #expect(!reopened.fanProtectionEnabled)
    let rule = FanPreset(name: "Work", mode: .fixed, rpm: 2500)
    #expect(await reopened.activate(rule, fanIDs: [0]))
    #expect(await reopened.activate(rule, fanIDs: [0, 1]))
    #expect(await hw.protectionRequests().suffix(2).allSatisfy { $0 == false })
    #expect(await reopened.setFanProtection(true))
    #expect(FanStore(hardware: hw, defaults: defaults, observeSleep: false).fanProtectionEnabled)
  }
  @Test func failedHelperUpdateKeepsPreviousPreferenceAndReportsError() async {
    let (store, hw, _, defaults) = ScheduleExecutionTests().fixture(.now)
    await hw.rejectProtectionUpdate()
    #expect(!(await store.setFanProtection(false)))
    #expect(store.fanProtectionEnabled && store.error != nil)
    #expect(FanStore(hardware: hw, defaults: defaults, observeSleep: false).fanProtectionEnabled)
  }
  @Test func changingToggleWhileBusyDoesNotPersistOrSendAControlChange() async {
    let (store, hw, _, _) = ScheduleExecutionTests().fixture(.now)
    store.busy = true
    #expect(!(await store.setFanProtection(false)))
    #expect(store.fanProtectionEnabled)
    #expect(await hw.protectionRequests().isEmpty)
  }
}
