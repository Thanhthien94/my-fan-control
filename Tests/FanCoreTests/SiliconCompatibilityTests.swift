import Foundation
import Testing

@testable import FanCore

struct SiliconCompatibilityTests {
  @Test(arguments: ["F0md", "F0Md"])
  func gateLessFirmwareMustConfirmAutomaticMode(mode: String) throws {
    var values: [String: Double] = [mode: 0, "F0Tg": 0]
    let driver = FanKeyController(
      read: { key in
        guard let value = values[key] else { throw FanError.read(key, -132) }
        return value
      },
      write: { key, value in
        // Firmware acknowledges automatic-mode writes but does not apply them.
        if key == mode, value == 0 { return }
        values[key] = value
      }, wait: { _ in })
    try driver.setTarget(
      fan: Fan(id: 0, name: "Fan", current: 1200, minimum: 1200, maximum: 6000), rpm: 2500)
    #expect(throws: (any Error).self) { try driver.restore(0) }
    #expect(driver.forced.contains(0))
  }

  @Test func missingControlKeysNeverTakeTheGlobalGate() {
    let hardware = FanKeyFake()
    hardware.values.removeValue(forKey: "F0Md")
    let driver = hardware.controller()
    #expect(throws: (any Error).self) {
      try driver.setTarget(
        fan: Fan(id: 0, name: "Fan", current: 1200, minimum: 1200, maximum: 6000), rpm: 2500)
    }
    #expect(hardware.writes.isEmpty)
    #expect(driver.forced.isEmpty)
  }

  @Test func legacyMaskMustConfirmManualBit() {
    var target = 0.0
    let driver = FanKeyController(
      read: { key in
        if key == "FS! " { return 0 }
        if key == "F0Tg" { return target }
        throw FanError.read(key, -132)
      }, write: { key, value in if key == "F0Tg" { target = value } }, wait: { _ in })
    #expect(throws: (any Error).self) {
      try driver.setTarget(
        fan: Fan(id: 0, name: "Fan", current: 1200, minimum: 1200, maximum: 6000), rpm: 2500)
    }
  }

  @Test func legacyMaskRestorationPreservesOtherFanBits() throws {
    var values: [String: Double] = ["FS! ": 2, "F0Tg": 0]
    let driver = FanKeyController(
      read: { key in
        guard let value = values[key] else { throw FanError.read(key, -132) }
        return value
      }, write: { values[$0] = $1 }, wait: { _ in })
    try driver.setTarget(
      fan: Fan(id: 0, name: "Fan", current: 1200, minimum: 1200, maximum: 6000), rpm: 2500)
    #expect(values["FS! "] == 3)
    try driver.restore(0)
    #expect(values["FS! "] == 2 && driver.forced.isEmpty)
  }

  @Test func globalHandbackAlsoClearsTheLegacyMask() throws {
    var values: [String: Double] = ["Ftst": 0, "FS! ": 2, "F0Tg": 0]
    let driver = FanKeyController(
      read: { key in
        guard let value = values[key] else { throw FanError.read(key, -132) }
        return value
      }, write: { values[$0] = $1 }, wait: { _ in })
    try driver.setTarget(
      fan: Fan(id: 0, name: "Fan", current: 1200, minimum: 1200, maximum: 6000), rpm: 2500)
    #expect(try driver.returnSystemControl())
    #expect(values["FS! "] == 2 && values["Ftst"] == 0)
  }

  @Test func gateLessAutomaticModeCanSettleAsynchronously() throws {
    var values: [String: Double] = ["F0md": 0, "F0Tg": 0]
    var waiting = false
    var polls = 0
    let driver = FanKeyController(
      read: { key in
        if key == "F0md", waiting {
          polls += 1
          if polls >= 3 { values[key] = 0 }
        }
        guard let value = values[key] else { throw FanError.read(key, -132) }
        return value
      }, write: { key, value in
        if key == "F0md", value == 0 { waiting = true; return }
        values[key] = value
      }, wait: { _ in })
    try driver.setTarget(
      fan: Fan(id: 0, name: "Fan", current: 1200, minimum: 1200, maximum: 6000), rpm: 2500)
    try driver.restore(0)
    #expect(polls >= 3 && driver.forced.isEmpty)
  }

  @Test(arguments: [-1.0, Double.nan, 65536.0, 0.5])
  func malformedLegacyMaskIsRejectedBeforeWrites(value: Double) {
    var writes = 0
    let driver = FanKeyController(
      read: { key in
        if key == "FS! " { return value }
        throw FanError.read(key, -132)
      }, write: { _, _ in writes += 1 }, wait: { _ in })
    #expect(throws: (any Error).self) {
      try driver.setTarget(
        fan: Fan(id: 0, name: "Fan", current: 1200, minimum: 1200, maximum: 6000), rpm: 2500)
    }
    #expect(writes == 0)
  }

  @Test func futureChipNamesNeverReuseM1Catalog() {
    #expect(!SensorCatalog.lookup("Tp0P", chip: "Apple M10 Pro").known)
    #expect(!SensorCatalog.lookup("Tp0P", chip: "Apple M1Unknown").known)
  }

  @Test func m5SensorsAndM1MemoryUseTheirOwnCatalog() {
    #expect(SensorCatalog.lookup("Tp0j", chip: "Apple M5").component == .cpu)
    #expect(SensorCatalog.lookup("Tg0U", chip: "Apple M5").component == .gpu)
    #expect(SensorCatalog.lookup("Tm02", chip: "Apple M1 Ultra").component == .memory)
    #expect(!SensorCatalog.lookup("Tg0U", chip: "Apple M4 Pro").known)
  }
}
