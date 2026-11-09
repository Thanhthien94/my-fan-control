import Testing

@testable import FanCore

private final class HardwareStub: FanHardware {
  let fan = Fan(id: 0, name: "Test", current: 2000, minimum: 1200, maximum: 6000)
  var sensors = [Sensor(id: "test", name: "Test", celsius: 50)]
  var readFails = false, writeFails = false, restoreFails = false
  var writes = [Double](), restores = [Int]()
  func snapshot() throws -> Snapshot {
    if readFails { throw FanError.unavailable }
    return Snapshot(fans: [fan], sensors: sensors)
  }
  func setTarget(fan: Fan, rpm: Double) throws {
    writes.append(rpm)
    if writeFails { throw FanError.invalid("Partial write failure") }
  }
  func restore(_ id: Int) throws {
    restores.append(id)
    if restoreFails { throw FanError.invalid("Transient restore failure") }
  }
}
struct SessionTests {
  @Test func testDisconnectRestoresAndStopsFurtherWrites() throws {
    let hw = HardwareStub()
    let control = ControlSession(hardware: hw)
    try control.configure(id: 0, rule: FanPreset(name: "Fixed", mode: .fixed, rpm: 2500))
    control.tick(leaseAge: 10)
    #expect(hw.restores == [0])
    #expect(control.owned.isEmpty)
    control.tick(leaseAge: 0)
    #expect(hw.writes == [2500])
  }
  @Test func testSensorLossAndHeatRestoreInsteadOfKeepingStaleTarget() throws {
    for failure in 0..<3 {
      let hw = HardwareStub()
      let control = ControlSession(hardware: hw)
      try control.configure(id: 0, rule: FanPreset(name: "Curve", mode: .sensor, sensor: "test"))
      if failure == 0 { hw.sensors = [] }
      if failure == 1 { hw.sensors[0].celsius = 95 }
      if failure == 2 { hw.readFails = true }
      control.tick(leaseAge: 1)
      #expect(hw.restores == [0])
      #expect(control.owned.isEmpty)
    }
  }
  @Test func testPartialWriteFailureAndFailedRestoreAreRetried() {
    let hw = HardwareStub()
    let control = ControlSession(hardware: hw)
    hw.writeFails = true
    hw.restoreFails = true
    #expect(throws: (any Error).self) {
      try control.configure(id: 0, rule: FanPreset(name: "Fixed", mode: .fixed, rpm: 2500))
    }
    #expect(control.owned == [0])
    #expect(hw.restores == [0])
    hw.restoreFails = false
    control.tick(leaseAge: 1)
    #expect(hw.restores == [0, 0])
    #expect(control.owned.isEmpty)
    #expect(hw.writes.count == 1)
  }
  @Test func testConfigureRequiresFreshSafeTelemetryBeforeWriting() {
    let hw = HardwareStub()
    let control = ControlSession(hardware: hw)
    hw.readFails = true
    #expect(throws: (any Error).self) {
      try control.configure(id: 0, rule: FanPreset(name: "Fixed", mode: .fixed, rpm: 2500))
    }
    #expect(hw.writes.isEmpty)
    hw.readFails = false
    hw.sensors = []
    #expect(throws: (any Error).self) {
      try control.configure(id: 0, rule: FanPreset(name: "Fixed", mode: .fixed, rpm: 2500))
    }
    #expect(hw.writes.isEmpty)
  }
}
