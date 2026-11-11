import Foundation
import Testing
@testable import FanCore

private final class MinimumHardware: FanHardware {
  var fans = [Fan(id: 0, name: "Left", current: 1500, minimum: 1200, maximum: 6000),
    Fan(id: 1, name: "Right", current: 1500, minimum: 1500, maximum: 5000)]
  var temperature = 40.0
  var targets = [Int: Double]()
  var restored = Set<Int>()
  var failWrites = false
  func snapshot() -> Snapshot {
    Snapshot(fans: fans, sensors: [Sensor(id: "test", name: "Test", celsius: temperature)])
  }
  func setTarget(fan: Fan, rpm: Double) throws {
    if failWrites { throw FanError.invalid("write failed") }
    targets[fan.id] = rpm
  }
  func restore(_ id: Int) { restored.insert(id) }
}

struct MinimumRPMTests {
  let fan = Fan(id: 0, name: "Fan", current: 2000, minimum: 1200, maximum: 6000)
  let curve = FanPreset(name: "Curve", mode: .sensor, sensor: "test", start: 40, full: 80)
  @Test func zeroFloorAndRaisedFloorDefineTheWholeCurve() throws {
    #expect(try curve.target(for: fan, temperature: 30, minimumRPM: 0) == 0)
    #expect(try curve.target(for: fan, temperature: 60, minimumRPM: 0) == 3000)
    #expect(try curve.target(for: fan, temperature: 85, minimumRPM: 0) == 6000)
    #expect(try curve.target(for: fan, temperature: 60, minimumRPM: 2000) == 4000)
    #expect(try curve.target(for: fan, temperature: 30) == 1200)
  }
  @Test func fixedZeroIsExplicitAndHigherFloorRaisesOldPresetTarget() throws {
    let zero = FanPreset(name: "Zero", mode: .fixed, rpm: 0)
    #expect(try zero.target(for: fan, temperature: nil, minimumRPM: 0) == 0)
    #expect(throws: (any Error).self) { try zero.target(for: fan, temperature: nil) }
    let low = FanPreset(name: "Low", mode: .fixed, rpm: 1500)
    #expect(try low.target(for: fan, temperature: nil, minimumRPM: 2500) == 2500)
  }
  @Test func invalidFloorsCannotGenerateTargets() {
    for value in [-1.0, .nan, .infinity, 6001] {
      #expect(throws: (any Error).self) {
        try curve.target(for: fan, temperature: 50, minimumRPM: value)
      }
    }
  }
  @Test func liveGlobalUpdateAffectsBothFansAndSubsequentSamples() throws {
    let hw = MinimumHardware()
    let session = ControlSession(hardware: hw)
    try session.configureGroup(ids: [0, 1], rule: curve, minimumRPM: 0)
    #expect(hw.targets == [0: 0, 1: 0])
    try session.setMinimumRPM(2000)
    #expect(hw.targets == [0: 2000, 1: 2000])
    hw.temperature = 60
    session.tick(leaseAge: 1)
    #expect(hw.targets == [0: 4000, 1: 3500])
    try session.setMinimumRPM(nil)
    hw.temperature = 40
    session.tick(leaseAge: 1)
    #expect(hw.targets == [0: 1200, 1: 1500])
  }
  @Test func disablingCustomFloorRaisesAnActiveZeroPresetToHardwareMinimum() throws {
    let hw = MinimumHardware()
    let session = ControlSession(hardware: hw)
    try session.configureGroup(ids: [0, 1], rule: FanPreset(name: "Stop", mode: .fixed, rpm: 0), minimumRPM: 0)
    try session.setMinimumRPM(nil)
    #expect(hw.targets == [0: 1200, 1: 1500])
    session.tick(leaseAge: 1)
    #expect(hw.targets == [0: 1200, 1: 1500])
  }
  @Test func invalidGroupFloorIsRejectedBeforeAnyWrite() {
    let hw = MinimumHardware()
    let session = ControlSession(hardware: hw)
    #expect(throws: (any Error).self) {
      try session.configureGroup(ids: [0, 1], rule: curve, minimumRPM: 5500)
    }
    #expect(hw.targets.isEmpty)
  }
  @Test func failedLiveUpdateReturnsOwnedFansToAutomatic() throws {
    let hw = MinimumHardware()
    let session = ControlSession(hardware: hw)
    try session.configureGroup(ids: [0, 1], rule: curve, minimumRPM: 0)
    hw.failWrites = true
    #expect(throws: (any Error).self) { try session.setMinimumRPM(2000) }
    #expect(session.owned.isEmpty && hw.restored == [0, 1])
  }
  @Test func helperColdStartCannotBeAcceleratedByRepeatedCommandsAndHeatStillRestores() throws {
    let hw = MinimumHardware()
    hw.fans = hw.fans.map { var fan = $0; fan.current = 0; return fan }
    var time = ContinuousClock.now
    let session = ControlSession(hardware: hw, now: { time })
    let fixed = FanPreset(name: "Fast", mode: .fixed, rpm: 4500)
    try session.configureGroup(ids: [0, 1], rule: fixed, minimumRPM: 0)
    #expect(hw.targets == [0: 200, 1: 200])
    try session.configureGroup(ids: [0, 1], rule: fixed, minimumRPM: 0)
    #expect(hw.targets == [0: 200, 1: 200])
    time = time.advanced(by: .seconds(1))
    session.tick(leaseAge: 1)
    #expect(hw.targets == [0: 400, 1: 400])
    hw.temperature = 90
    session.tick(leaseAge: 1)
    #expect(hw.restored == [0, 1] && session.activeIDs.isEmpty)
    #expect(hw.targets == [0: 400, 1: 400])
    hw.temperature = 40
    try session.configure(id: 0, rule: fixed, minimumRPM: 0)
    #expect(hw.targets[0] == 200)
  }
  @Test func zeroTargetStillRequiresSMCTargetAndModeAcknowledgement() throws {
    let hw = FanKeyFake()
    let driver = hw.controller()
    try driver.setTarget(fan: fan, rpm: 0)
    #expect(hw.values["F0Tg"] == 0 && hw.values["F0Md"] == 1)
    try driver.restore(0)
    #expect(hw.values["Ftst"] == 0)
    #expect(throws: (any Error).self) { try driver.setTarget(fan: fan, rpm: -1) }
  }
}
