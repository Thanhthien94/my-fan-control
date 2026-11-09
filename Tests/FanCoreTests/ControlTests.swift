import Foundation
import Testing

@testable import FanCore

struct ControlTests {
  private let fan = Fan(id: 0, name: "Test", current: 2000, minimum: 1200, maximum: 6000)
  @Test func testTemperatureCurveReachesHardwareBounds() throws {
    let rule = FanPreset(name: "Curve", mode: .sensor, start: 40, full: 80)
    #expect(try rule.target(for: fan, temperature: 30) == 1200)
    #expect(try rule.target(for: fan, temperature: 60) == 3600)
    #expect(try rule.target(for: fan, temperature: 89) == 6000)
  }
  @Test func testInvalidOrMissingSensorNeverProducesManualTarget() {
    let rule = FanPreset(name: "Curve", mode: .sensor)
    for t: Double? in [nil, .nan, .infinity, -1, 130] {
      #expect(throws: (any Error).self) { try rule.target(for: fan, temperature: t) }
    }
    #expect(throws: (any Error).self) {
      try FanPreset(name: "Bad", mode: .sensor, start: 80, full: 40).target(
        for: fan, temperature: 60)
    }
    #expect(throws: (any Error).self) {
      try FanPreset(name: "Bad", mode: .fixed, rpm: 0).target(for: fan, temperature: nil)
    }
    #expect(throws: (any Error).self) {
      try FanPreset(name: "Bad", mode: .fixed, rpm: .nan).target(for: fan, temperature: nil)
    }
  }
  @Test func testExpiredLeaseAndHotOrMissingTelemetryRestoreAutomatic() {
    let normal = [Sensor(id: "Tp01", name: "Temperature", celsius: 50)]
    #expect(ControlSafety.permits(leaseAge: 9, sensors: normal))
    #expect(!(ControlSafety.permits(leaseAge: 10, sensors: normal)))
    #expect(!(ControlSafety.permits(leaseAge: -1, sensors: normal)))
    #expect(!(ControlSafety.permits(leaseAge: 1, sensors: [])))
    #expect(
      !(ControlSafety.permits(leaseAge: 1, sensors: [Sensor(id: "hot", name: "Hot", celsius: 90)])))
    #expect(
      !(ControlSafety.permits(leaseAge: 1, sensors: [Sensor(id: "nan", name: "NaN", celsius: .nan)]))
    )
  }
  @Test func testSMCEncodingAcrossIntelAndAppleSilicon() {
    #expect(SMC.decode(type: "flt ", bytes: [0, 0, 72, 66]) == 50)
    #expect(SMC.decode(type: "sp78", bytes: [0x32, 0x80]) == 50.5)
    #expect(SMC.decode(type: "sp78", bytes: [0xff, 0x80]) == -0.5)
    #expect(SMC.decode(type: "fpe2", bytes: [0x27, 0x10]) == 2500)
    #expect(SMC.decode(type: "flt ", bytes: [0, 0, 128, 127]) == nil)
    #expect(SMC.decode(type: "sp78", bytes: [0]) == nil)
    #expect(SMC.decode(type: "unknown", bytes: [0]) == nil)
  }
  @Test func testPresetRoundTripKeepsSensorAndThresholds() throws {
    let original = FanPreset(name: "Render", mode: .sensor, sensor: "Tp09", start: 45, full: 75)
    #expect(
      try JSONDecoder().decode(FanPreset.self, from: JSONEncoder().encode(original)) == original)
  }
}
