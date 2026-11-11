import Foundation
import Testing
@testable import FanCore

private final class KeepSpinningHardware: FanHardware {
  var fans = [Fan(id: 0, name: "Left", current: 0, minimum: 1200, maximum: 6000),
    Fan(id: 1, name: "Right", current: 0, minimum: 1500, maximum: 5000)]
  var temperature = 35.0
  var targets = [Int: Double]()
  var restores = Set<Int>()
  var failWrites = false
  func snapshot() -> Snapshot {
    Snapshot(fans: fans, sensors: [Sensor(id: "test", name: "Test", celsius: temperature)])
  }
  func setTarget(fan: Fan, rpm: Double) throws {
    if failWrites { throw FanError.invalid("Write rejected") }
    targets[fan.id] = rpm
  }
  func restore(_ id: Int) { restores.insert(id) }
}

struct KeepSpinningProtectionTests {
  @Test func zeroFixedAndCoolCurveUseEachFansOwnHardwareFloorWhenProtected() throws {
    for rule in [FanPreset(name: "Stop", mode: .fixed, rpm: 0),
      FanPreset(name: "Curve", mode: .sensor, sensor: "test")] {
      let hw = KeepSpinningHardware()
      let session = ControlSession(hardware: hw)
      try session.configureGroup(ids: [0, 1], rule: rule, minimumRPM: 0)
      #expect(hw.targets == [0: 1200, 1: 1500])
      session.tick(leaseAge: 1)
      #expect(hw.targets == [0: 1200, 1: 1500])
    }
  }
  @Test func disablingRestoresExplicitZeroAndReenablingImmediatelyRestoresFloor() throws {
    let hw = KeepSpinningHardware()
    let session = ControlSession(hardware: hw)
    try session.configureGroup(ids: [0, 1], rule: FanPreset(name: "Stop", mode: .fixed, rpm: 0), minimumRPM: 0)
    try session.setFanProtection(false)
    #expect(hw.targets == [0: 0, 1: 0])
    try session.setFanProtection(true)
    #expect(hw.targets == [0: 1200, 1: 1500])
  }
  @Test func explicitHigherFloorWinsAndChangingCustomZeroCannotBypassProtection() throws {
    let hw = KeepSpinningHardware()
    let session = ControlSession(hardware: hw)
    let curve = FanPreset(name: "Curve", mode: .sensor, sensor: "test")
    try session.configureGroup(ids: [0, 1], rule: curve, minimumRPM: 2000)
    #expect(hw.targets == [0: 2000, 1: 2000])
    try session.setMinimumRPM(0)
    #expect(hw.targets == [0: 1200, 1: 1500])
  }
  @Test func failedToggleRetainsPreviousChoiceAndRestoresOwnedFans() throws {
    let hw = KeepSpinningHardware()
    let session = ControlSession(hardware: hw)
    try session.configureGroup(ids: [0, 1], rule: FanPreset(name: "Stop", mode: .fixed, rpm: 0), minimumRPM: 0)
    hw.failWrites = true
    #expect(throws: (any Error).self) { try session.setFanProtection(false) }
    #expect(session.fanProtectionEnabled)
    #expect(session.owned.isEmpty && hw.restores == [0, 1])
  }
  @Test func thermalReturnToAutomaticOverridesKeepSpinningPolicy() throws {
    let hw = KeepSpinningHardware()
    let session = ControlSession(hardware: hw)
    try session.configureGroup(ids: [0, 1], rule: FanPreset(name: "Stop", mode: .fixed, rpm: 0), minimumRPM: 0)
    hw.temperature = 90
    session.tick(leaseAge: 1)
    #expect(session.owned.isEmpty && hw.restores == [0, 1])
  }
}
