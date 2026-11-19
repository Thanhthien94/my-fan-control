import FanCore
import Foundation
import Testing
@testable import MyFanControl

@MainActor struct ThermalThresholdWorkflowTests {
  @Test func choicePersistsAndReachesSingleAndGroupCommands() async {
    let (store, hw, _, defaults) = ScheduleExecutionTests().fixture(.now)
    #expect(store.thermalThreshold == 90)
    #expect(await store.setThermalThreshold(150))
    let reopened = FanStore(hardware: hw, defaults: defaults, observeSleep: false)
    #expect(reopened.thermalThreshold == 150)
    let rule = FanPreset(name: "Work", mode: .fixed, rpm: 2500)
    #expect(await reopened.activate(rule, fanIDs: [0]))
    #expect(await reopened.activate(rule, fanIDs: [0, 1]))
    #expect(await hw.thresholdRequests() == [150, 150, 150])
  }
  @Test func busyInvalidOrRejectedUpdatesPreservePreviousPreference() async {
    let (store, hw, _, defaults) = ScheduleExecutionTests().fixture(.now)
    store.busy = true
    #expect(!(await store.setThermalThreshold(100)))
    store.busy = false
    for value in [Double.nan, .infinity, 59, 151] {
      #expect(!(await store.setThermalThreshold(value)))
    }
    #expect(await hw.thresholdRequests().isEmpty)
    await hw.rejectThresholdUpdate()
    #expect(!(await store.setThermalThreshold(100)))
    #expect(store.thermalThreshold == 90)
    #expect(FanStore(hardware: hw, defaults: defaults, observeSleep: false).thermalThreshold == 90)
  }
  @Test func corruptStoredValueFallsBackToDefault() {
    let (_, hw, _, defaults) = ScheduleExecutionTests().fixture(.now)
    defaults.set(200, forKey: "thermalThreshold")
    #expect(FanStore(hardware: hw, defaults: defaults, observeSleep: false).thermalThreshold == 90)
  }
}
