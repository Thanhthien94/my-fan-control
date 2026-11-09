import Foundation
import Testing

@testable import FanCore

struct OperationBudgetTests {
  @Test func slowFirmwareCannotConsumeAnUnboundedManualRequest() {
    let start = ContinuousClock.now
    var instant = start
    var target = 0.0
    let driver = FanKeyController(
      read: { key in
        if key == "F0md" { return 0 }
        if key == "F0Tg" { return target }
        throw FanError.read(key, -132)
      }, write: { key, value in if key == "F0Tg" { target = value } },
      wait: { instant = instant.advanced(by: .seconds($0)) }, now: { instant })
    driver.beginControlOperation()
    #expect(throws: (any Error).self) {
      try driver.setTarget(fan: Fan(id: 0, name: "Fan", current: 1200, minimum: 1200, maximum: 6000), rpm: 2000)
    }
    #expect(start.duration(to: instant) <= .seconds(25.2))
    #expect(driver.forced.contains(0))
    #expect(throws: Never.self) { try driver.restore(0) }
    #expect(driver.forced.isEmpty)
  }
  @Test func oneGroupSharesOneOperationBudget() throws {
    let hardware = BudgetHardware()
    let session = ControlSession(hardware: hardware)
    try session.configureGroup(ids: [0, 1], rule: FanPreset(name: "Work", mode: .fixed, rpm: 2000))
    #expect(hardware.begins == 1)
    session.tick(leaseAge: 1)
    #expect(hardware.begins == 2)
  }
}
private final class BudgetHardware: FanHardware {
  var begins = 0
  func beginControlOperation() { begins += 1 }
  func snapshot() -> Snapshot {
    Snapshot(fans: [0, 1].map { Fan(id: $0, name: "Fan", current: 1200, minimum: 1200, maximum: 6000) },
      sensors: [Sensor(id: "test", name: "Temperature", celsius: 50)])
  }
  func setTarget(fan: Fan, rpm: Double) {}
  func restore(_ id: Int) {}
}
