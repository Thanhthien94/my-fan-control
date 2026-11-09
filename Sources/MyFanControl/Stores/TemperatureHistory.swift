import Foundation

/// One hour at the default one-second polling cadence, bounded even after manual refreshes.
enum TemperatureHistory {
  static func retaining(_ points: [TemperaturePoint], asOf now: Date) -> [TemperaturePoint] {
    let cutoff = now.addingTimeInterval(-3600)
    return Array(points.filter { $0.date >= cutoff && $0.date <= now }.suffix(3600))
  }
}
