import CSMC
import Foundation

public final class SMC {
  private let connection: UInt32
  private var temperatureKeys: [String]?
  public init() throws {
    connection = mfc_open()
    guard connection != 0 else { throw FanError.unavailable }
  }
  deinit { mfc_close(connection) }
  static func code(_ text: String) -> UInt32 { text.utf8.reduce(0) { ($0 << 8) | UInt32($1) } }
  public static func decode(type: String, bytes: [UInt8]) -> Double? {
    switch type {
    case "flt ":
      guard bytes.count == 4 else { return nil }
      let bits = bytes.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << ($1.offset * 8) }
      let value = Double(Float(bitPattern: bits))
      return value.isFinite ? value : nil
    case "sp78":
      guard bytes.count == 2 else { return nil }
      return Double(Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256
    case "fpe2":
      guard bytes.count == 2 else { return nil }
      return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4
    case "ui8 ": return bytes.count == 1 ? Double(bytes[0]) : nil
    case "ui16": return bytes.count == 2 ? Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) : nil
    case "ui32":
      return bytes.count == 4 ? Double(bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }) : nil
    default: return nil
    }
  }
  private func read(_ key: String) throws -> MFCValue {
    var value = MFCValue()
    let status = mfc_read(connection, key, &value)
    guard status == 0 else { throw FanError.read(key, status) }
    return value
  }
  public func number(_ key: String) throws -> Double {
    var value = try read(key)
    let bytes = withUnsafeBytes(of: &value.bytes) { Array($0.prefix(Int(value.size))) }
    let type =
      String(bytes: (0..<4).map { UInt8((value.type >> (24 - $0 * 8)) & 255) }, encoding: .ascii)
      ?? ""
    guard let n = Self.decode(type: type, bytes: bytes) else {
      throw FanError.invalid(L10n.f("error.readType", key, type))
    }
    return n
  }
  private func discoverTemperatures() throws -> [String] {
    let n = try number("#KEY")
    guard n.isFinite, n > 0, n <= 50000 else {
      throw FanError.invalid(L10n.t("Số lượng SMC key không hợp lệ."))
    }
    var keys = [String]()
    var chars = [CChar](repeating: 0, count: 5)
    for i in 0..<Int(n) {
      if mfc_key_at(connection, UInt32(i), &chars) == 0 {
        let key = String(cString: chars)
        if key.hasPrefix("T"), let value = try? read(key),
          value.type == Self.code("flt ") || value.type == Self.code("sp78")
        {
          keys.append(key)
        }
      }
    }
    return keys.sorted()
  }
  public func snapshot() throws -> Snapshot {
    let count = try number("FNum")
    guard count >= 0, count <= 10 else {
      throw FanError.invalid(L10n.t("Số lượng quạt không hợp lệ."))
    }
    let fans = try (0..<Int(count)).map { i -> Fan in
      let current = try number("F\(i)Ac")
      let minimum = try number("F\(i)Mn")
      let maximum = try number("F\(i)Mx")
      guard current.isFinite, minimum.isFinite, maximum.isFinite, current >= 0, current <= 20000,
        minimum >= 0, maximum > minimum, maximum <= 20000
      else { throw FanError.invalid(L10n.f("error.fanData", i)) }
      let manual: Bool
      if let mode = try? number("F\(i)Md") {
        manual = mode == 1
      } else {
        manual = (Int((try? number("FS! ")) ?? 0) & (1 << i)) != 0
      }
      return Fan(
        id: i,
        name: Int(count) == 2
          ? (i == 0 ? L10n.t("Quạt trái") : L10n.t("Quạt phải")) : L10n.f("fan.name", i + 1),
        current: current, minimum: minimum, maximum: maximum, target: try? number("F\(i)Tg"),
        manual: manual)
    }
    if temperatureKeys == nil { temperatureKeys = try discoverTemperatures() }
    let sensors = (temperatureKeys ?? []).compactMap { key -> Sensor? in
      guard let t = try? number(key), t > 0, t < 130 else { return nil }
      return Sensor(id: key, name: Self.sensorName(key), celsius: t)
    }
    return Snapshot(fans: fans, sensors: sensors)
  }
  public static func sensorName(_ key: String) -> String {
    SensorCatalog.lookup(key).name
  }
  private func writeNumber(_ key: String, _ number: Double) throws {
    var value = try read(key)
    guard number.isFinite, number >= 0 else {
      throw FanError.invalid(L10n.t("Giá trị không hợp lệ."))
    }
    let bytes: [UInt8]
    switch value.type {
    case Self.code("flt "):
      let bits = Float(number).bitPattern
      bytes = (0..<4).map { UInt8((bits >> ($0 * 8)) & 255) }
    case Self.code("fpe2"):
      guard number <= 16383 else { throw FanError.invalid(L10n.t("RPM vượt kiểu fpe2.")) }
      let v = UInt16((number * 4).rounded())
      bytes = [UInt8(v >> 8), UInt8(v & 255)]
    case Self.code("ui8 "):
      guard number <= 255 else { throw FanError.invalid(L10n.t("Giá trị vượt ui8.")) }
      bytes = [UInt8(number)]
    case Self.code("ui16"):
      guard number <= 65535 else { throw FanError.invalid(L10n.t("Giá trị vượt ui16.")) }
      let v = UInt16(number)
      bytes = [UInt8(v >> 8), UInt8(v & 255)]
    default: throw FanError.invalid(L10n.f("error.writeType", key))
    }
    guard bytes.count == value.size else {
      throw FanError.invalid(L10n.t("Kích thước SMC không khớp."))
    }
    withUnsafeMutableBytes(of: &value.bytes) { $0.copyBytes(from: bytes) }
    let result = mfc_write(connection, key, &value)
    guard result == 0 else { throw FanError.read(key, result) }
  }
  public func setTarget(fan: Fan, rpm: Double) throws {
    guard (0..<10).contains(fan.id), rpm.isFinite, rpm >= fan.minimum, rpm <= fan.maximum else {
      throw FanError.invalid(L10n.t("RPM nằm ngoài giới hạn phần cứng."))
    }
    // Set a bounded target before enabling manual mode.
    try writeNumber("F\(fan.id)Tg", rpm)
    try setManual(fan.id, true)
    guard let target = try? number("F\(fan.id)Tg"), abs(target - rpm) < 2 else {
      try? restore(fan.id)
      throw FanError.invalid(L10n.t("SMC không xác nhận RPM mục tiêu."))
    }
  }
  private func setManual(_ id: Int, _ manual: Bool) throws {
    if (try? read("F\(id)Md")) != nil {
      try writeNumber("F\(id)Md", manual ? 1 : 0)
    } else {
      let existing = Int(try number("FS! "))
      let mask = 1 << id
      try writeNumber("FS! ", Double(manual ? existing | mask : existing & ~mask))
    }
    let actual: Bool
    if let mode = try? number("F\(id)Md") {
      actual = mode == 1
    } else {
      actual = (Int(try number("FS! ")) & (1 << id)) != 0
    }
    guard actual == manual else {
      throw FanError.invalid(L10n.t("Không xác nhận được chế độ quạt."))
    }
  }
  public func restore(_ id: Int) throws {
    guard (0..<10).contains(id) else { throw FanError.invalid(L10n.t("Fan ID không hợp lệ.")) }
    try setManual(id, false)
  }
}
