import Foundation
import Testing

@testable import FanCore

struct SMCTelemetryTests {
  private func reader(_ values: [String: Double]) -> SMCTelemetryReader {
    SMCTelemetryReader(
      number: { key in
        guard let value = values[key] else { throw FanError.read(key, -132) }
        return value
      }, temperatureKeys: { ["TB1T"] })
  }

  @Test func fanlessSMCStillReturnsTemperature() throws {
    let snapshot = try reader(["FNum": 0, "TB1T": 34]).snapshot()
    #expect(snapshot.fans.isEmpty)
    #expect(snapshot.fanAvailability == .noneReported)
    #expect(snapshot.sensors.first?.celsius == 34)
  }

  @Test func unavailableFanCountIsDistinctFromFanless() throws {
    let snapshot = try reader(["TB1T": 34]).snapshot()
    #expect(snapshot.fans.isEmpty)
    #expect(snapshot.fanAvailability == .unavailable)
    #expect(snapshot.sensors.count == 1)
  }

  @Test func invalidFanTelemetryKeepsMonitoringButOffersNoControls() throws {
    let snapshot = try reader([
      "FNum": 1, "F0Ac": 1200, "F0Mn": 6000, "F0Mx": 5000, "TB1T": 34,
    ]).snapshot()
    #expect(snapshot.fanAvailability == .unavailable)
    #expect(snapshot.fans.isEmpty && snapshot.sensors.count == 1)
  }

  @Test(arguments: [1, 2, 4])
  func topologyUsesReportedCountAndPerFanLimits(count: Int) throws {
    var values: [String: Double] = ["FNum": Double(count), "TB1T": 34]
    for id in 0..<count {
      values["F\(id)Ac"] = Double(1200 + id * 100)
      values["F\(id)Mn"] = Double(1200 + id * 100)
      values["F\(id)Mx"] = Double(5000 + id * 100)
      values["F\(id)md"] = 0
    }
    let snapshot = try reader(values).snapshot()
    #expect(snapshot.fanAvailability == .available)
    #expect(snapshot.fans.count == count)
    #expect(snapshot.fans.last?.minimum == Double(1200 + (count - 1) * 100))
    #expect(snapshot.fans.last?.maximum == Double(5000 + (count - 1) * 100))
  }

  @Test(arguments: [-1.0, 0.5, 11.0, Double.nan, Double.infinity])
  func malformedCountNeverBecomesValidFans(count: Double) throws {
    let snapshot = try reader(["FNum": count, "TB1T": 34]).snapshot()
    #expect(snapshot.fanAvailability == .unavailable && snapshot.fans.isEmpty)
  }
}
