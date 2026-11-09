import Darwin
import Foundation

public enum SensorComponent: String, CaseIterable, Sendable {
  case cpu, gpu, memory, battery, storage, wireless, airflow, mainboard, display, thunderbolt,
    unknown
  public var title: String { L10n.t("component." + rawValue) }
  public var explanation: String { L10n.t("component." + rawValue + ".detail") }
}

public struct SensorInfo: Sendable {
  public var name: String
  public var component: SensorComponent
  public var known: Bool { component != .unknown }
  public var explanation: String { component.explanation }
  public let sourceURL =
    "https://github.com/exelban/stats/blob/1a4a9a6079196cf1ba87124eca2b6ba4e674024a/Modules/Sensors/values.swift"
}

public enum HardwareIdentity {
  public static let chip: String = {
    var size = 0
    guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else {
      return "Unknown"
    }
    var bytes = [CChar](repeating: 0, count: size)
    guard sysctlbyname("machdep.cpu.brand_string", &bytes, &size, nil, 0) == 0 else {
      return "Unknown"
    }
    return String(cString: bytes)
  }()
}

/// Exact, case-sensitive, generation-scoped community mappings; never guess from a prefix.
/// Mapping facts adapted from Stats (MIT); see THIRD_PARTY_NOTICES.md and docs/sensors.md.
public enum SensorCatalog {
  public static func lookup(_ key: String, chip: String = HardwareIdentity.chip) -> SensorInfo {
    func info(_ name: String, _ component: SensorComponent) -> SensorInfo {
      SensorInfo(name: name, component: component)
    }
    func indexed(_ keys: [String], _ label: String, _ component: SensorComponent) -> SensorInfo? {
      guard let i = keys.firstIndex(of: key) else { return nil }
      return info(L10n.f(label, i + 1), component)
    }
    let apple = chip.hasPrefix("Apple ")
    let chipParts = chip.split(separator: " ")
    let family = chipParts.count >= 2 && chipParts[0] == "Apple" ? String(chipParts[1]) : ""
    let number = family.hasPrefix("M") ? Int(family.dropFirst()) : nil
    let generation = number.flatMap { (1...5).contains($0) ? $0 : nil }
    if let generation {
      let efficiency: [String]
      let performance: [String]
      let gpu: [String]
      switch generation {
      case 1:
        efficiency = ["Tp09", "Tp0T"]
        performance = ["Tp01", "Tp05", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0X", "Tp0b"]
        gpu = ["Tg05", "Tg0D", "Tg0L", "Tg0T"]
      case 2:
        efficiency = ["Tp1h", "Tp1t", "Tp1p", "Tp1l"]
        performance = ["Tp01", "Tp05", "Tp09", "Tp0D", "Tp0X", "Tp0b", "Tp0f", "Tp0j"]
        gpu = ["Tg0f", "Tg0j"]
      case 3:
        efficiency = ["Te05", "Te0L", "Te0P", "Te0S"]
        performance = [
          "Tf04", "Tf09", "Tf0A", "Tf0B", "Tf0D", "Tf0E", "Tf44", "Tf49", "Tf4A", "Tf4B", "Tf4D",
          "Tf4E",
        ]
        gpu = ["Tf14", "Tf18", "Tf19", "Tf1A", "Tf24", "Tf28", "Tf29", "Tf2A"]
      case 4:
        efficiency = ["Te05", "Te0S", "Te09", "Te0H"]
        performance = ["Tp01", "Tp05", "Tp09", "Tp0D", "Tp0V", "Tp0Y", "Tp0b", "Tp0e"]
        gpu =
          (chip.contains("Pro") || chip.contains("Max") ? ["Tg1U", "Tg1k"] : ["Tg0G", "Tg0H"]) + [
            "Tg0K", "Tg0L", "Tg0d", "Tg0e", "Tg0j", "Tg0k",
          ]
      default:  // M5: catalog labels are sensor groups, not verified physical core identities.
        efficiency = []
        performance = [
          "Tp00", "Tp04", "Tp08", "Tp0C", "Tp0G", "Tp0K", "Tp0O", "Tp0R", "Tp0U", "Tp0X",
          "Tp0a", "Tp0d", "Tp0g", "Tp0j", "Tp0m", "Tp0p", "Tp0u", "Tp0y",
        ]
        gpu = ["Tg0U", "Tg0X", "Tg0d", "Tg0g", "Tg0j", "Tg1Y", "Tg1c", "Tg1g"]
      }
      if generation == 1, let match = indexed(["Tm02", "Tm06", "Tm08", "Tm09"], "sensor.memory", .memory) {
        return match
      }
      if let match = indexed(efficiency, "sensor.cpu.efficiency", .cpu) { return match }
      if let match = indexed(performance, generation == 5 ? "sensor.cpu" : "sensor.cpu.performance", .cpu) { return match }
      if let match = indexed(gpu, "sensor.gpu", .gpu) { return match }
      if generation == 4, let match = indexed(["Tm0p", "Tm1p", "Tm2p"], "sensor.memory", .memory) {
        return match
      }
    }
    if apple {
      switch key {
      case "TB1T", "TB2T": return info(L10n.f("sensor.battery", key == "TB1T" ? 1 : 2), .battery)
      case "TH0x": return info(L10n.t("sensor.nand"), .storage)
      case "TaLP": return info(L10n.t("sensor.air.left"), .airflow)
      case "TaRF": return info(L10n.t("sensor.air.right"), .airflow)
      default: break
      }
    }
    let common: [String: (String, SensorComponent)] = [
      "TC0D": ("sensor.cpu.diode", .cpu), "TC0H": ("sensor.cpu.heatsink", .cpu),
      "TC0P": ("sensor.cpu.proximity", .cpu), "TCAD": ("sensor.cpu.package", .cpu),
      "TG0D": ("sensor.gpu.diode", .gpu), "TG0H": ("sensor.gpu.heatsink", .gpu),
      "TG0P": ("sensor.gpu.proximity", .gpu),
      "Tm0P": ("sensor.mainboard", .mainboard), "TW0P": ("sensor.wifi", .wireless),
      "TL0P": ("sensor.display", .display), "TTLD": ("sensor.thunderbolt.left", .thunderbolt),
      "TTRD": ("sensor.thunderbolt.right", .thunderbolt),
    ]
    if let (label, component) = common[key] { return info(L10n.t(label), component) }
    if !apple, chip.contains("Intel") {
      if key == "Tp0P" { return info(L10n.t("sensor.powerboard"), .mainboard) }
      if key == "TB1T" { return info(L10n.f("sensor.battery", 1), .battery) }
    }
    return info(L10n.f("sensor.unidentified", key), .unknown)
  }
}
