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
  @Test func alreadySpinningFansRampFromTheirFloorsToTargetInsteadOfJumping() throws {
    let hw = KeepSpinningHardware()
    hw.fans = hw.fans.map { var fan = $0; fan.current = fan.minimum; return fan }
    var time = ContinuousClock.now
    let session = ControlSession(hardware: hw, now: { time })
    try session.configureGroup(ids: [0, 1], rule: FanPreset(name: "Fast", mode: .fixed, rpm: 4500), minimumRPM: 0)
    #expect(hw.targets == [0: 1200, 1: 1500])
    for step in 1...7 {
      time = time.advanced(by: .seconds(1))
      session.tick(leaseAge: 1)
      #expect(hw.targets[0] == min(4500, 1200 + Double(step) * 500))
      #expect(hw.targets[1] == min(4500, 1500 + Double(step) * 500))
    }
  }
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
  @Test func rawZeroAndClampedDisplayKeepIdentityButRealEditsRemainVisible() {
    let stored = FanPreset(name: "Stop", mode: .fixed, rpm: 0)
    var displayed = stored
    displayed.rpm = 1350
    #expect(stored.sameControl(as: displayed, atMinimumRPM: 1350))
    displayed.rpm = 1500
    #expect(!stored.sameControl(as: displayed, atMinimumRPM: 1350))
    displayed = stored
    displayed.id = UUID()
    #expect(!stored.sameControl(as: displayed, atMinimumRPM: 1350))
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
