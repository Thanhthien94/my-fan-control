import Foundation

public protocol FanHardware: AnyObject {
  func snapshot() throws -> Snapshot
  func setTarget(fan: Fan, rpm: Double) throws
  func restore(_ id: Int) throws
  func beginControlOperation()
  func restoreSystemControl() throws -> Bool
}
extension FanHardware {
  public func restoreSystemControl() throws -> Bool { false }
  public func beginControlOperation() {}
}
extension SMC: FanHardware {}

/// Used by the privileged helper. No UI state is trusted as hardware telemetry.
public final class ControlSession {
  private let hardware: FanHardware
  private var rules = [Int: FanPreset]()
  public private(set) var owned = Set<Int>()
  public var activeIDs: Set<Int> { Set(rules.keys) }
  public var restoringIDs: Set<Int> { owned.subtracting(activeIDs) }
  public private(set) var notice: String?
  public init(hardware: FanHardware) { self.hardware = hardware }
  public func acknowledgeNotice() { notice = nil }

  @discardableResult public func restoreAll() -> Bool {
    rules.removeAll()
    restoreOrphans()
    return owned.isEmpty
  }
  private func restoreOrphans() {
    if rules.isEmpty, !owned.isEmpty {
      do {
        if try hardware.restoreSystemControl() {
          owned.removeAll()
          return
        }
      } catch {
        notice = error.localizedDescription
        return
      }
    }
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
      hardware.beginControlOperation()
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
    hardware.beginControlOperation()
    try configureWithinOperation(id: id, rule: rule)
  }
  private func configureWithinOperation(id: Int, rule: FanPreset) throws {
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
  public func configureGroup(ids: [Int], rule: FanPreset) throws {
    guard !ids.isEmpty, ids.count <= 10, Set(ids).count == ids.count,
      ids.allSatisfy({ (0..<10).contains($0) })
    else {
      throw FanError.invalid(L10n.t("group.invalid"))
    }
    hardware.beginControlOperation()
    let snapshot = try hardware.snapshot()
    // Validate the entire group before the first write. Each configure also rereads telemetry.
    for id in ids {
      guard let fan = snapshot.fans.first(where: { $0.id == id }) else {
        throw FanError.invalid(L10n.t("Không tìm thấy quạt."))
      }
      _ = try rule.target(
        for: fan, temperature: snapshot.sensors.first(where: { $0.id == rule.sensor })?.celsius)
    }
    var touched = Set<Int>()
    do {
      for id in ids.sorted() {
        touched.insert(id)
        try configureWithinOperation(id: id, rule: rule)
      }
    } catch {
      // Physical writes are sequential, so failure returns the touched group to automatic.
      for id in touched {
        rules.removeValue(forKey: id)
        owned.insert(id)
      }
      restoreOrphans()
      throw error
    }
  }
}
