import Foundation
import FanCore
import Testing

@testable import MyFanControl

@MainActor struct CompletenessTests {
  @Test func disablingAnActiveScheduleCancelsAndRestoresItsFans() async {
    let base = Date()
    let fixture = ScheduleExecutionTests()
    let (store, hardware, schedules, _) = fixture.fixture(base)
    let item = fixture.job(base)
    schedules.items = [item]
    await schedules.tick(store: store, now: base.addingTimeInterval(2))
    await schedules.changeEnabled(item.id, false, store: store)
    #expect(schedules.running.isEmpty)
    #expect(await hardware.ids().isEmpty)
    #expect(!schedules.items[0].enabled)
  }
  @Test func invalidPresetCannotEnterTheSavedLibrary() {
    let (store, _, _, _) = ScheduleExecutionTests().fixture(Date())
    #expect(store.save(FanPreset(name: "Bad", mode: .sensor, sensor: "Tp01", start: 1e100, full: 75)) == nil)
    #expect(store.presets.isEmpty)
  }
}
