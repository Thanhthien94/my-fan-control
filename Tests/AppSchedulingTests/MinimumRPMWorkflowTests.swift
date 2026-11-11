import FanCore
import Foundation
import Testing
@testable import MyFanControl

@MainActor struct MinimumRPMWorkflowTests {
  @Test func globalZeroPersistsAndIsPassedForSingleAndGroupActivation() async {
    let (store, hw, _, defaults) = ScheduleExecutionTests().fixture(.now)
    #expect(store.minimumRPM == nil)
    #expect(await store.setMinimumRPM(0))
    let reopened = FanStore(hardware: hw, defaults: defaults, observeSleep: false)
    #expect(reopened.minimumRPM == 0)
    let zero = FanPreset(name: "Zero", mode: .fixed, rpm: 0)
    #expect(await reopened.activate(zero, fanIDs: [0]))
    #expect(await reopened.activate(zero, fanIDs: [0, 1]))
    #expect(await hw.minimumRequests().suffix(2).allSatisfy { $0 == 0 })
    #expect(await reopened.setMinimumRPM(nil))
    #expect(FanStore(hardware: hw, defaults: defaults, observeSleep: false).minimumRPM == nil)
  }
  @Test func invalidSettingDoesNotReplaceTheSavedFloor() async {
    let (store, _, _, _) = ScheduleExecutionTests().fixture(.now)
    #expect(await store.setMinimumRPM(0))
    for value in [-1.0, .nan, .infinity, 6001] {
      #expect(!(await store.setMinimumRPM(value)))
      #expect(store.minimumRPM == 0)
    }
  }
}
