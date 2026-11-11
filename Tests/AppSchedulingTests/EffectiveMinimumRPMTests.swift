import FanCore
import Foundation
import Testing
@testable import MyFanControl

@MainActor struct EffectiveMinimumRPMTests {
  @Test func storedZeroSurvivesToggleWhileEditorEffectiveFloorTracksProtection() async {
    let (store, _, _, _) = ScheduleExecutionTests().fixture(.now)
    let left = Fan(id: 0, name: "Left", current: 0, minimum: 1200, maximum: 6000)
    let right = Fan(id: 1, name: "Right", current: 0, minimum: 1500, maximum: 5000)
    #expect(await store.setMinimumRPM(0))
    #expect(store.effectiveMinimumRPM(for: left) == 1200)
    #expect(store.effectiveMinimumRPM(for: right) == 1500)
    #expect(await store.setFanProtection(false))
    #expect(store.minimumRPM == 0 && store.effectiveMinimumRPM(for: left) == 0)
    #expect(await store.setFanProtection(true))
    #expect(store.minimumRPM == 0 && store.effectiveMinimumRPM(for: right) == 1500)
  }
}
