import Foundation
import Testing
@testable import FanCore

private final class ThresholdHardware: FanHardware {
  var temperature = 95.0
  var restored = false
  func snapshot() -> Snapshot {
    Snapshot(fans: [Fan(id: 0, name: "Fan", current: 1500, minimum: 1200, maximum: 6000)],
      sensors: [Sensor(id: "test", name: "Test", celsius: temperature)])
  }
  func setTarget(fan: Fan, rpm: Double) {}
  func restore(_ id: Int) { restored = true }
}
struct ThermalThresholdTests {
  @Test func customThresholdGovernsAdmissionTickAndImmediateLowering() throws {
    let hw = ThresholdHardware()
    let session = ControlSession(hardware: hw)
    let rule = FanPreset(name: "Work", mode: .fixed, rpm: 2500)
    #expect(throws: (any Error).self) { try session.configure(id: 0, rule: rule) }
    try session.setThermalThreshold(100)
    try session.configure(id: 0, rule: rule)
    session.tick(leaseAge: 1)
    #expect(session.activeIDs == [0])
    try session.setThermalThreshold(95)
    #expect(hw.restored && session.activeIDs.isEmpty)
  }
  @Test func invalidThresholdsCannotDisableSafety() throws {
    let session = ControlSession(hardware: ThresholdHardware())
    for value in [Double.nan, .infinity, 59, 111] {
      #expect(throws: (any Error).self) { try session.setThermalThreshold(value) }
      #expect(session.thermalThreshold == 90)
    }
  }
  @Test func hottestSensorAndLeaseStillGovernCustomThreshold() {
    let sensors = [Sensor(id: "cool", name: "Cool", celsius: 50), Sensor(id: "hot", name: "Hot", celsius: 100)]
    #expect(!ControlSafety.permits(leaseAge: 1, sensors: sensors, threshold: 100))
    #expect(ControlSafety.permits(leaseAge: 1, sensors: sensors, threshold: 105))
    #expect(!ControlSafety.permits(leaseAge: 10, sensors: sensors, threshold: 105))
    #expect(!ControlSafety.permits(leaseAge: 1, sensors: [], threshold: 105))
  }
}
