import Foundation

public enum TemperatureUnit: String, Sendable {
  case celsius, fahrenheit
  public var symbol: String { self == .fahrenheit ? "°F" : "°C" }
  public func value(_ celsius: Double) -> Double { self == .fahrenheit ? celsius * 1.8 + 32 : celsius }
  public func text(_ celsius: Double, decimals: Int = 1) -> String {
    String(format: "%.*f%@", decimals, value(celsius), symbol)
  }
}
public enum SensorCSV {
  public static func export(_ snapshot: Snapshot, unit: TemperatureUnit) -> String {
    func cell(_ text: String) -> String {
      let safe = ["=", "+", "-", "@", "\t", "\r", "\n"].contains(where: { text.hasPrefix($0) }) ? "'" + text : text
      return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    var lines = [["SMC key", "Sensor", unit.symbol].map(cell).joined(separator: ",")]
    for sensor in snapshot.sensors {
      lines.append([cell(sensor.id), cell(sensor.name), String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), unit.value(sensor.celsius))].joined(separator: ","))
    }
    return lines.joined(separator: "\r\n") + "\r\n"
  }
}
