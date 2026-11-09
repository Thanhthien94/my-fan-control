import Foundation
import Testing

@testable import MyFanControl

@MainActor struct MonitoringHistoryTests {
  @Test func fasterPollingStillKeepsAnHourOfHistory() {
    let now = Date()
    let points = (-3599...0).map { TemperaturePoint(date: now.addingTimeInterval(Double($0)), temperature: 50) }
    let retained = TemperatureHistory.retaining(points, asOf: now)
    #expect(retained.count == 3600)
    #expect(retained.first?.date == points.first?.date)
  }
  @Test func expiredAndFutureReadingsDoNotPolluteTheCurrentChart() {
    let now = Date()
    let points = [-3601.0, -1801.0, 0.0, 100.0].map { TemperaturePoint(date: now.addingTimeInterval($0), temperature: 50) }
    #expect(TemperatureHistory.retaining(points, asOf: now).count == 2)
  }
}
