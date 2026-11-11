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
  private var minimums = [Int: Double]()
  private var startup = FanStartupRamp()
  private let now: () -> ContinuousClock.Instant
  public private(set) var owned = Set<Int>()
  public var activeIDs: Set<Int> { Set(rules.keys) }
  public var restoringIDs: Set<Int> { owned.subtracting(activeIDs) }
  public private(set) var notice: String?
  public init(hardware: FanHardware, now: @escaping () -> ContinuousClock.Instant = { .now }) {
    self.hardware = hardware
    self.now = now
  }
  private func writeTarget(fan: Fan, rpm: Double) throws {
    try hardware.setTarget(fan: fan, rpm: startup.target(for: fan, requested: rpm, at: now()))
  }
  /// Change the global floor for currently active rules without changing their saved definitions.
  public func setMinimumRPM(_ value: Double?) throws {
    if let value, !value.isFinite || value < 0 || value > 20000 {
      throw FanError.invalid(L10n.f("rpm.minimumInvalid", 20000))
    }
    guard !rules.isEmpty else { return }
    hardware.beginControlOperation()
    let snapshot = try hardware.snapshot()
    let targets = try rules.map { id, rule -> (Fan, Double) in
      guard let fan = snapshot.fans.first(where: { $0.id == id }) else {
        throw FanError.invalid(L10n.t("Không tìm thấy quạt."))
      }
      let floor = value ?? (rule.mode == .fixed && rule.rpm < fan.minimum ? fan.minimum : nil)
      guard let rpm = try rule.target(for: fan, sensors: snapshot.sensors, minimumRPM: floor)
      else { throw FanError.invalid(L10n.t("Không tìm thấy quạt.")) }
      return (fan, rpm)
    }
    do {
      guard ControlSafety.permits(leaseAge: 0, sensors: snapshot.sensors) else {
        throw FanError.invalid(L10n.t("Đã về tự động: nhiệt độ cao, mất cảm biến hoặc hết phiên."))
      }
      for (fan, rpm) in targets { try writeTarget(fan: fan, rpm: rpm) }
      for (fan, _) in targets {
        minimums[fan.id] = value ?? (rules[fan.id]?.mode == .fixed && (rules[fan.id]?.rpm ?? 0) < fan.minimum ? fan.minimum : nil)
      }
    } catch {
      restoreAll()
      throw error
    }
  }
  public func acknowledgeNotice() { notice = nil }

  @discardableResult public func restoreAll() -> Bool {
    rules.removeAll()
    minimums.removeAll()
    startup.reset()
    restoreOrphans()
    return owned.isEmpty
  }
  private func restoreOrphans() {
    if rules.isEmpty, !owned.isEmpty {
      do {
        if try hardware.restoreSystemControl() {
          owned.removeAll()
          minimums.removeAll()
          startup.reset()
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
        minimums.removeValue(forKey: id)
        startup.reset(id)
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
            for: fan, sensors: snapshot.sensors, minimumRPM: minimums[id])
        else {
          throw FanError.invalid(L10n.t("Cảm biến hoặc quạt không còn khả dụng."))
        }
        return (fan, rpm)
      }
      for (fan, rpm) in targets { try writeTarget(fan: fan, rpm: rpm) }
    } catch {
      notice = error.localizedDescription
      restoreAll()
    }
  }
  public func configure(id: Int, rule: FanPreset, minimumRPM: Double? = nil) throws {
    hardware.beginControlOperation()
    try configureWithinOperation(id: id, rule: rule, minimumRPM: minimumRPM)
  }
  private func configureWithinOperation(id: Int, rule: FanPreset, minimumRPM: Double?) throws {
    guard (0..<10).contains(id) else { throw FanError.invalid(L10n.t("Fan ID không hợp lệ.")) }
    // Read afresh at the privilege boundary; a cached snapshot cannot authorize writes.
    let snapshot = try hardware.snapshot()
    guard let fan = snapshot.fans.first(where: { $0.id == id }) else {
      throw FanError.invalid(L10n.t("Không tìm thấy quạt."))
    }
    if let rpm = try rule.target(for: fan, sensors: snapshot.sensors, minimumRPM: minimumRPM) {
      guard ControlSafety.permits(leaseAge: 0, sensors: snapshot.sensors) else {
        throw FanError.invalid(
          L10n.t("Cần cảm biến nhiệt hợp lệ dưới 90°C để điều khiển thủ công."))
      }
      owned.insert(id)
      do {
        try writeTarget(fan: fan, rpm: rpm)
        rules[id] = rule
        minimums[id] = minimumRPM
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
      minimums.removeValue(forKey: id)
      startup.reset(id)
      try hardware.restore(id)
      owned.remove(id)
      notice = nil
    }
  }
  public func configureGroup(ids: [Int], rule: FanPreset, minimumRPM: Double? = nil) throws {
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
        for: fan, sensors: snapshot.sensors, minimumRPM: minimumRPM)
    }
    var touched = Set<Int>()
    do {
      for id in ids.sorted() {
        touched.insert(id)
        try configureWithinOperation(id: id, rule: rule, minimumRPM: minimumRPM)
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
