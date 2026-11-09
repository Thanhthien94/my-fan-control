import Foundation

/// Detect fans from readable capabilities rather than a marketing-model allowlist.
/// A missing or invalid fan channel must not hide otherwise valid temperatures.
final class SMCTelemetryReader {
  let number: (String) throws -> Double
  let temperatureKeys: () throws -> [String]
  init(
    number: @escaping (String) throws -> Double,
    temperatureKeys: @escaping () throws -> [String]
  ) {
    self.number = number
    self.temperatureKeys = temperatureKeys
  }
  func snapshot() throws -> Snapshot {
    let fans: [Fan]
    let availability: FanAvailability
    do {
      fans = try readFans()
      availability = fans.isEmpty ? .noneReported : .available
    } catch {
      // Offer no writable fans if any fan's count or bounds cannot be validated.
      fans = []
      availability = .unavailable
    }
    let sensors = try temperatureKeys().compactMap { key -> Sensor? in
      guard let value = try? number(key), value.isFinite, value > 0, value < 130 else { return nil }
      return Sensor(id: key, name: SensorCatalog.lookup(key).name, celsius: value)
    }
    return Snapshot(fans: fans, sensors: sensors, fanAvailability: availability)
  }
  private func readFans() throws -> [Fan] {
    let count = try number("FNum")
    guard count.isFinite, count >= 0, count <= 10, count.rounded(.towardZero) == count else {
      throw FanError.invalid(L10n.t("Số lượng quạt không hợp lệ."))
    }
    return try (0..<Int(count)).map { id in
      let current = try number("F\(id)Ac")
      let minimum = try number("F\(id)Mn")
      let maximum = try number("F\(id)Mx")
      guard current.isFinite, minimum.isFinite, maximum.isFinite, current >= 0, current <= 20000,
        minimum >= 0, maximum > minimum, maximum <= 20000
      else { throw FanError.invalid(L10n.f("error.fanData", id)) }
      let manual: Bool
      if let mode = (try? number("F\(id)md")) ?? (try? number("F\(id)Md")) {
        manual = FanKeyController.isManual(mode: mode, gate: try? number("Ftst"))
      } else {
        let mask = (try? number("FS! ")) ?? 0
        guard mask.isFinite, mask >= 0, mask <= 65535 else {
          throw FanError.invalid(L10n.f("error.fanData", id))
        }
        manual = (Int(mask) & (1 << id)) != 0
      }
      // Fan ordering is SMC ordering; two fans do not imply a universal left/right layout.
      return Fan(
        id: id, name: L10n.f("fan.name", id + 1), current: current,
        minimum: minimum, maximum: maximum, target: try? number("F\(id)Tg"), manual: manual)
    }
  }
}
