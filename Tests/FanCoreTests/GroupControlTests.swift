import Foundation
import Testing

@testable import FanCore

final class GroupHardware: FanHardware {
  var fans = [
    Fan(id: 0, name: "Left", current: 2000, minimum: 1000, maximum: 6000),
    Fan(id: 1, name: "Right", current: 2000, minimum: 1500, maximum: 5000),
  ]
  var writes = [Int](), restores = [Int]()
  var failFan: Int?
  func snapshot() -> Snapshot {
    Snapshot(fans: fans, sensors: [Sensor(id: "test", name: "Test", celsius: 50)])
  }
  func setTarget(fan: Fan, rpm: Double) throws {
    writes.append(fan.id)
    if fan.id == failFan { throw FanError.invalid("Injected write failure") }
  }
  func restore(_ id: Int) { restores.append(id) }
}
struct GroupControlTests {
  @Test func appliesBothFansAndChecksAllLimitsBeforeWriting() throws {
    let hw = GroupHardware()
    let control = ControlSession(hardware: hw)
    #expect(throws: (any Error).self) {
      try control.configureGroup(
        ids: [0, 1], rule: FanPreset(name: "Too low", mode: .fixed, rpm: 1200))
    }
    #expect(hw.writes.isEmpty)
    try control.configureGroup(ids: [0, 1], rule: FanPreset(name: "Both", mode: .fixed, rpm: 2500))
    #expect(hw.writes == [0, 1])
    #expect(control.owned == [0, 1])
  }
  @Test func partialFailureRestoresTouchedFans() {
    let hw = GroupHardware()
    let session = ControlSession(hardware: hw)
    hw.failFan = 1
    #expect(throws: (any Error).self) {
      try session.configureGroup(
        ids: [0, 1], rule: FanPreset(name: "Both", mode: .fixed, rpm: 2500))
    }
    #expect(hw.writes == [0, 1])
    #expect(Set(hw.restores) == [0, 1])
    #expect(session.owned.isEmpty)
  }
  @Test func duplicateIDsAreRejected() {
    let hw = GroupHardware()
    let control = ControlSession(hardware: hw)
    #expect(throws: (any Error).self) {
      try control.configureGroup(
        ids: [0, 0], rule: FanPreset(name: "Both", mode: .fixed, rpm: 2500))
    }
    #expect(hw.writes.isEmpty)
  }
}
