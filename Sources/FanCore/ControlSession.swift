import Foundation

public protocol FanHardware: AnyObject {
  func snapshot() throws -> Snapshot
  func setTarget(fan: Fan, rpm: Double) throws
  func restore(_ id: Int) throws
}
extension SMC: FanHardware {}

/// Used by the privileged helper. No UI state is trusted as hardware telemetry.
public final class ControlSession {
  private let hardware: FanHardware
  private var rules = [Int: FanPreset]()
  public private(set) var owned = Set<Int>()
  public private(set) var notice: String?
  public init(hardware: FanHardware) { self.hardware = hardware }

  @discardableResult public func restoreAll() -> Bool {
    rules.removeAll()
    restoreOrphans()
    return owned.isEmpty
  }
  private func restoreOrphans() {
    for id in owned.sorted() where rules[id] == nil {
      do {
        try hardware.restore(id)
        owned.remove(id)
      } catch { notice = L10n.f("error.restore", id + 1, error.localizedDescription) }
    }
  }
  public func tick(leaseAge: Double) {
    restoreOrphans()
    guard !rules.isEmpty else { return }
    do {
      let snapshot = try hardware.snapshot()
      guard ControlSafety.permits(leaseAge: leaseAge, sensors: snapshot.sensors) else {
        throw FanError.invalid(L10n.t("Đã về tự động: nhiệt độ cao, mất cảm biến hoặc hết phiên."))
      }
      // Resolve every target before writing any fan.
      let targets = try rules.map { id, rule -> (Fan, Double) in
        guard let fan = snapshot.fans.first(where: { $0.id == id }),
          let rpm = try rule.target(
            for: fan, temperature: snapshot.sensors.first(where: { $0.id == rule.sensor })?.celsius)
        else {
          throw FanError.invalid(L10n.t("Cảm biến hoặc quạt không còn khả dụng."))
        }
        return (fan, rpm)
      }
      for (fan, rpm) in targets { try hardware.setTarget(fan: fan, rpm: rpm) }
    } catch {
      notice = error.localizedDescription
      restoreAll()
    }
  }
  public func configure(id: Int, rule: FanPreset) throws {
    guard (0..<10).contains(id) else { throw FanError.invalid(L10n.t("Fan ID không hợp lệ.")) }
    // Read afresh at the privilege boundary; a cached snapshot cannot authorize writes.
    let snapshot = try hardware.snapshot()
    guard let fan = snapshot.fans.first(where: { $0.id == id }) else {
      throw FanError.invalid(L10n.t("Không tìm thấy quạt."))
    }
    let t = snapshot.sensors.first(where: { $0.id == rule.sensor })?.celsius
    if let rpm = try rule.target(for: fan, temperature: t) {
      guard ControlSafety.permits(leaseAge: 0, sensors: snapshot.sensors) else {
        throw FanError.invalid(
          L10n.t("Cần cảm biến nhiệt hợp lệ dưới 90°C để điều khiển thủ công."))
      }
      owned.insert(id)
      do {
        try hardware.setTarget(fan: fan, rpm: rpm)
        rules[id] = rule
        notice = nil
      } catch {
        rules.removeValue(forKey: id)
        restoreOrphans()
        throw error
      }
    } else {
      // Track restore failures too, so the next tick retries them.
      owned.insert(id)
      rules.removeValue(forKey: id)
      try hardware.restore(id)
      owned.remove(id)
      notice = nil
    }
  }
}
