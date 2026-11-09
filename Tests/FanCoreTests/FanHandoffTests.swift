import Foundation
import Testing

@testable import FanCore

final class FanKeyFake {
  var values: [String: Double] = ["FNum": 2, "Ftst": 0, "F0Md": 3, "F1Md": 3, "F0Tg": 0, "F1Tg": 0]
  var writes = [String](), waits = [Double]()
  var failTarget: String?
  func read(_ key: String) throws -> Double {
    guard let v = values[key] else { throw FanError.read(key, -132) }
    return v
  }
  func write(_ key: String, _ value: Double) throws {
    writes.append("\(key)=\(value)")
    if key == failTarget { throw FanError.read(key, -130) }
    if key.hasSuffix("Md"), value == 1, values["Ftst"] == 0 { throw FanError.read(key, -130) }
    values[key] = value
    if key == "Ftst", value == 0 {
      for mode in ["F0Md", "F1Md"] where values[mode] == 0 { values[mode] = 3 }
    }
  }
  func controller() -> FanKeyController {
    FanKeyController(read: read, write: write, wait: { self.waits.append($0) })
  }
}
struct FanHandoffTests {
  @Test func systemOwnedModeOneIsNotAUserForcedFan() {
    #expect(!FanKeyController.isManual(mode: 1, gate: 0))
    #expect(FanKeyController.isManual(mode: 1, gate: 1))
    #expect(FanKeyController.isManual(mode: 1, gate: nil))
    #expect(!FanKeyController.isManual(mode: 3, gate: 0))
  }
  @Test func targetIsWrittenBeforeCheckingForcedMode() throws {
    let hw = FanKeyFake()
    let driver = FanKeyController(
      read: hw.read,
      write: { key, value in
        if key == "F0Md", value == 1, hw.values["Ftst"] == 1 { return }
        if key == "F0Tg", value > 0 { hw.values["F0Md"] = 1 }
        try hw.write(key, value)
      }, wait: { _ in })
    try driver.setTarget(
      fan: Fan(id: 0, name: "Left", current: 0, minimum: 1350, maximum: 5777), rpm: 2500)
    #expect(hw.values["F0Md"] == 1 && hw.values["F0Tg"] == 2500)
    try driver.restore(0)
    #expect(hw.values["Ftst"] == 0)
  }
  let fan = Fan(id: 0, name: "Left", current: 0, minimum: 1350, maximum: 5777)
  @Test func m4HandoffAndLastFanRestoreReturnControlToMacOS() throws {
    let hw = FanKeyFake()
    let driver = hw.controller()
    try driver.setTarget(fan: fan, rpm: 2500)
    #expect(hw.values["Ftst"] == 1 && hw.values["F0Md"] == 1 && hw.values["F0Tg"] == 2500)
    #expect(hw.waits.contains(3))
    try driver.restore(0)
    #expect(hw.values["Ftst"] == 0 && hw.values["F0Md"] == 3)
    #expect(driver.forced.isEmpty)
  }
  @Test func restoringOneFanDoesNotResetTheOtherFan() throws {
    let hw = FanKeyFake()
    let driver = hw.controller()
    try driver.setTarget(fan: fan, rpm: 2500)
    try driver.setTarget(
      fan: Fan(id: 1, name: "Right", current: 0, minimum: 1350, maximum: 5777), rpm: 2500)
    try driver.restore(0)
    #expect(hw.values["Ftst"] == 1 && hw.values["F1Md"] == 1)
    try driver.restore(1)
    #expect(hw.values["Ftst"] == 0)
  }
  @Test func failedSpeedWriteStillAllowsGlobalCleanup() {
    let hw = FanKeyFake()
    let driver = hw.controller()
    hw.failTarget = "F0Tg"
    #expect(throws: (any Error).self) { try driver.setTarget(fan: fan, rpm: 2500) }
    hw.failTarget = nil
    #expect(throws: Never.self) { try driver.restore(0) }
    #expect(hw.values["Ftst"] == 0 && driver.forced.isEmpty)
  }
  @Test func alreadyAutomaticReadonlyModeNeedsNoModeWrite() throws {
    let hw = FanKeyFake()
    let driver = hw.controller()
    try driver.restore(0)
    #expect(hw.writes.isEmpty)
  }
  @Test func lowercaseModeIsPreferredWhenAvailable() throws {
    let hw = FanKeyFake()
    hw.values["F0md"] = 0
    hw.values.removeValue(forKey: "Ftst")
    let driver = hw.controller()
    try driver.setTarget(fan: fan, rpm: 2500)
    #expect(hw.values["F0md"] == 1 && hw.values["Ftst"] == nil)
    #expect(!hw.waits.contains(3))
  }
  @Test func failedControllerOwnershipIsNotReportedAsActive() {
    let hw = HardwareFailForOwnership()
    let session = ControlSession(hardware: hw)
    #expect(throws: (any Error).self) {
      try session.configure(id: 0, rule: FanPreset(name: "Test", mode: .fixed, rpm: 2500))
    }
    #expect(session.activeIDs.isEmpty)
    #expect(session.restoringIDs == [0])
  }
}
final class HardwareFailForOwnership: FanHardware {
  func snapshot() -> Snapshot {
    Snapshot(
      fans: [Fan(id: 0, name: "Left", current: 0, minimum: 1350, maximum: 5777)],
      sensors: [Sensor(id: "test", name: "Test", celsius: 50)])
  }
  func setTarget(fan: Fan, rpm: Double) throws { throw FanError.invalid("Denied") }
  func restore(_ id: Int) throws { throw FanError.invalid("Retry required") }
}
