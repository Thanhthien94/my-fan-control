import FanCore
import Foundation
import Testing
@testable import MyFanControl

@MainActor struct RemovedMinimumSettingTests {
  @Test func legacyGlobalMinimumIsRemovedAndCannotChangeHardwareBounds() {
    for value in [0.0, 4000] {
      let (_, hw, _, defaults) = ScheduleExecutionTests().fixture(.now)
      defaults.set(value, forKey: "minimumRPM")
      defaults.set(false, forKey: "fanProtectionEnabled")
      let store = FanStore(hardware: hw, defaults: defaults, observeSleep: false)
      let fan = Fan(id: 0, name: "Left", current: 1500, minimum: 1350, maximum: 5777)
      #expect(store.effectiveMinimumRPM(for: fan) == 1350)
      #expect(defaults.object(forKey: "minimumRPM") == nil)
      #expect(!store.fanProtectionEnabled)
    }
  }
  @Test func removingLegacySettingPreservesSavedPresets() throws {
    let (old, hw, _, defaults) = ScheduleExecutionTests().fixture(.now)
    let preset = FanPreset(name: "Work", mode: .fixed, rpm: 3150)
    old.save(preset)
    defaults.set(0.0, forKey: "minimumRPM")
    let reopened = FanStore(hardware: hw, defaults: defaults, observeSleep: false)
    #expect(reopened.presets == [preset])
    #expect(defaults.object(forKey: "minimumRPM") == nil)
  }
}
