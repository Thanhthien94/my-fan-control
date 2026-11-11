import Foundation
import Testing
@testable import FanCore

private final class ProtectionHardware: FanHardware {
  let fan = Fan(id: 0, name: "Fan", current: 0, minimum: 1200, maximum: 6000)
  var temperature = 50.0
  var targets = [Double]()
  var restored = false
  func snapshot() -> Snapshot {
    Snapshot(fans: [fan], sensors: [Sensor(id: "test", name: "Test", celsius: temperature)])
  }
  func setTarget(fan: Fan, rpm: Double) { targets.append(rpm) }
  func restore(_ id: Int) { restored = true }
}

struct FanProtectionTests {
  @Test func enabledByDefaultAndSwitchingOffOnUsesTheChosenBehavior() throws {
    let hw = ProtectionHardware()
    let instant = ContinuousClock.now
    let session = ControlSession(hardware: hw, now: { instant })
    let rule = FanPreset(name: "Fast", mode: .fixed, rpm: 4500)
    #expect(session.fanProtectionEnabled)
    try session.configure(id: 0, rule: rule, minimumRPM: 0)
    #expect(hw.targets.last == 1200)
    try session.setFanProtection(false)
    session.tick(leaseAge: 1)
    #expect(hw.targets.last == 4500)
    try session.setFanProtection(true)
    session.tick(leaseAge: 1)
    #expect(hw.targets.last == 1200)
  }
  @Test func turningProtectionOffNeverTurnsThermalProtectionOff() throws {
    let hw = ProtectionHardware()
    let instant = ContinuousClock.now
    let session = ControlSession(hardware: hw, now: { instant })
    try session.setFanProtection(false)
    try session.configure(id: 0, rule: FanPreset(name: "Fast", mode: .fixed, rpm: 4500), minimumRPM: 0)
    hw.temperature = 90
    session.tick(leaseAge: 1)
    #expect(hw.restored && session.activeIDs.isEmpty)
    #expect(hw.targets == [4500])
  }
}
