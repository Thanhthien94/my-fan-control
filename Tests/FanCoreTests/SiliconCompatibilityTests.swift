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
