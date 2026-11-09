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
  private lazy var telemetry = SMCTelemetryReader(
    number: { [unowned self] in try self.number($0) },
    temperatureKeys: { [unowned self] in
      if self.temperatureKeys == nil { self.temperatureKeys = try self.discoverTemperatures() }
      return self.temperatureKeys ?? []
    })
  public func snapshot() throws -> Snapshot { try telemetry.snapshot() }
  /// Read-only, deliberately excludes serial numbers, user names and raw sensor dumps.
  public func compatibilityReport() throws -> CompatibilityReport {
    let reading = try snapshot()
    return CompatibilityReport(
      chip: HardwareIdentity.chip, model: HardwareIdentity.model,
      fanAvailability: reading.fanAvailability ?? .unavailable,
      gateAvailable: (try? number("Ftst")) != nil,
      fans: reading.fans.map { fan in
        let mode = (try? number("F\(fan.id)md")) != nil ? "F\(fan.id)md"
          : ((try? number("F\(fan.id)Md")) != nil ? "F\(fan.id)Md" : nil)
        return CompatibilityReport.FanCapability(
          fan: fan, modeKey: mode, legacyMaskAvailable: (try? number("FS! ")) != nil,
          targetAvailable: (try? number("F\(fan.id)Tg")) != nil)
      }, readableTemperatureCount: reading.sensors.count,
      mappedTemperatureCount: reading.sensors.filter { SensorCatalog.lookup($0.id).known }.count)
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
  private lazy var fanController = FanKeyController(
    read: { [unowned self] in try self.number($0) },
    write: { [unowned self] in try self.writeNumber($0, $1) },
    cancelled: { mfc_stop_requested() != 0 })
  public func setTarget(fan: Fan, rpm: Double) throws {
    try fanController.setTarget(fan: fan, rpm: rpm)
  }
  public func restore(_ id: Int) throws { try fanController.restore(id) }
  public func restoreSystemControl() throws -> Bool { try fanController.returnSystemControl() }
  public func explicitSystemAutomatic() throws {
    if try fanController.returnSystemControl(explicit: true) { return }
    for fan in try snapshot().fans { try restore(fan.id) }
  }
}
