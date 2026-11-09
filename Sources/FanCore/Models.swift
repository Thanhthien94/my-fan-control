import Foundation

public struct Fan: Codable, Identifiable, Equatable, Sendable {
  public var id: Int
  public var name: String
  public var current: Double
  public var minimum: Double
  public var maximum: Double
  public var target: Double?
  public var manual: Bool
  public init(
    id: Int, name: String, current: Double, minimum: Double, maximum: Double,
    target: Double? = nil, manual: Bool = false
  ) {
    self.id = id
    self.name = name
    self.current = current
    self.minimum = minimum
    self.maximum = maximum
    self.target = target
    self.manual = manual
  }
}
public struct Sensor: Codable, Identifiable, Equatable, Sendable {
  public var id: String
  public var name: String
  public var celsius: Double
  public init(id: String, name: String, celsius: Double) {
    self.id = id
    self.name = name
    self.celsius = celsius
  }
}
public struct Snapshot: Codable, Sendable {
  public var fans: [Fan]
  public var sensors: [Sensor]
  public var date: Date
  public init(fans: [Fan], sensors: [Sensor], date: Date = Date()) {
    self.fans = fans
    self.sensors = sensors
    self.date = date
  }
}
public enum FanError: LocalizedError {
  case unavailable
  case read(String, Int32)
  case invalid(String)
  case helper(String)
  public var errorDescription: String? {
    switch self {
    case .unavailable: return L10n.t("Không mở được AppleSMC trên máy này.")
    case .read(let key, let code): return L10n.f("error.smc", key, code)
    case .invalid(let message), .helper(let message): return message
    }
  }
}

public struct FanPreset: Codable, Identifiable, Equatable, Sendable {
  public var id: UUID = UUID()
  public var name: String
  public var mode: Mode
  public var rpm: Double
  public var sensor: String
  public var start: Double
  public var full: Double
  public enum Mode: String, Codable, CaseIterable, Sendable { case automatic, fixed, sensor }
  public init(
    name: String, mode: Mode, rpm: Double = 2500, sensor: String = "",
    start: Double = 45, full: Double = 80
  ) {
    self.name = name
    self.mode = mode
    self.rpm = rpm
    self.sensor = sensor
    self.start = start
    self.full = full
  }
  public func target(for fan: Fan, temperature: Double?) throws -> Double? {
    guard fan.minimum.isFinite, fan.maximum.isFinite, fan.minimum >= 0,
      fan.maximum > fan.minimum, fan.maximum <= 20000
    else { throw FanError.invalid(L10n.t("Giới hạn quạt không hợp lệ.")) }
    switch mode {
    case .automatic: return nil
    case .fixed:
      guard rpm.isFinite, rpm >= fan.minimum, rpm <= fan.maximum else {
        throw FanError.invalid(L10n.f("error.rpmBounds", Int(fan.minimum), Int(fan.maximum)))
      }
      return rpm
    case .sensor:
      guard start.isFinite, full.isFinite, start >= 20, full <= 90, full - start >= 5,
        let t = temperature, t.isFinite, t > 0, t < 130
      else {
        throw FanError.invalid(
          L10n.t("Cảm biến mất dữ liệu hoặc ngưỡng nhiệt không hợp lệ (20–90°C, cách ít nhất 5°C).")
        )
      }
      let ratio = max(0, min(1, (t - start) / (full - start)))
      return fan.minimum + ratio * (fan.maximum - fan.minimum)
    }
  }
}
