import Foundation
import Testing
@testable import FanCore

/// Opening Apple's shared control gate can spin the other fan before its turn.
private final class SharedGateStartupHardware: FanHardware {
  var fans = [
    Fan(id: 0, name: "Left", current: 0, minimum: 1350, maximum: 5777),
    Fan(id: 1, name: "Right", current: 0, minimum: 1350, maximum: 5777),
  ]
  var temperature = 50.0
  var targets = [Int: Double]()
  var restored = Set<Int>()
  var reads = 0
  var gateOpened = false
  var heatOnGate = false
  var onGate: () -> Void = {}
  func snapshot() -> Snapshot {
    reads += 1
    return Snapshot(fans: fans, sensors: [Sensor(id: "test", name: "CPU", celsius: temperature)])
  }
  func setTarget(fan: Fan, rpm: Double) {
    if !gateOpened {
      gateOpened = true
      // Models the side effect of Ftst handoff, not a user target for fan 1.
      fans[1].current = 1600
      if heatOnGate { temperature = 95 }
      onGate()
    }
    targets[fan.id] = rpm
  }
  func restore(_ id: Int) { restored.insert(id) }
}

struct GroupStartupProtectionTests {
  @Test func sharedGateSpinupCannotSkipRightFanProtectionAndHandoffTimeGivesNoRampCredit() throws {
    let hw = SharedGateStartupHardware()
    var time = ContinuousClock.now
    hw.onGate = { time = time.advanced(by: .seconds(3)) }
    let session = ControlSession(hardware: hw, now: { time })
    try session.configureGroup(ids: [1, 0],
      rule: FanPreset(name: "Both", mode: .fixed, rpm: 4500))
    #expect(hw.reads >= 3) // Group baseline plus fresh per-fan privilege-boundary reads.
    #expect(hw.targets == [0: 1350, 1: 1350])
    time = time.advanced(by: .seconds(1))
    session.tick(leaseAge: 1)
    #expect(hw.targets == [0: 1850, 1: 1850])
  }
  @Test func keepingStartupBaselineDoesNotReuseStaleSafetyTemperatures() {
    let hw = SharedGateStartupHardware()
    hw.heatOnGate = true
    let session = ControlSession(hardware: hw)
    #expect(throws: (any Error).self) {
      try session.configureGroup(ids: [0, 1],
        rule: FanPreset(name: "Both", mode: .fixed, rpm: 4500))
    }
    #expect(hw.targets[0] == 1350 && hw.targets[1] == nil)
    #expect(hw.restored == [0, 1] && session.owned.isEmpty)
  }
  @Test func rightFanOnItsOwnStillUsesSoftStartup() throws {
    let hw = SharedGateStartupHardware()
    let session = ControlSession(hardware: hw)
    try session.configure(id: 1, rule: FanPreset(name: "Right", mode: .fixed, rpm: 4500))
    #expect(hw.targets == [1: 1350])
  }
}
