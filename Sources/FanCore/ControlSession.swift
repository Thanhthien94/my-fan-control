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
  private var startup = FanStartupRamp()
  public private(set) var fanProtectionEnabled = true
  public func setFanProtection(_ enabled: Bool) throws {
    guard enabled != fanProtectionEnabled else { return }
    let previous = fanProtectionEnabled
    fanProtectionEnabled = enabled
    startup.reset()
    guard !rules.isEmpty else { return }
    do {
      hardware.beginControlOperation()
      let snapshot = try hardware.snapshot()
      guard ControlSafety.permits(leaseAge: 0, sensors: snapshot.sensors) else {
        throw FanError.invalid(L10n.t("Đã về tự động: nhiệt độ cao, mất cảm biến hoặc hết phiên."))
      }
      let targets = try rules.map { id, rule -> (Fan, Double) in
        guard let fan = snapshot.fans.first(where: { $0.id == id }),
          let rpm = try rule.target(for: fan, sensors: snapshot.sensors) else {
          throw FanError.invalid(L10n.t("Không tìm thấy quạt."))
        }
        return (fan, rpm)
      }
      for (fan, rpm) in targets { try writeTarget(fan: fan, rpm: rpm) }
    } catch {
      fanProtectionEnabled = previous
      restoreAll()
      throw error
    }
  }
  private let now: () -> ContinuousClock.Instant
  public private(set) var owned = Set<Int>()
  public var activeIDs: Set<Int> { Set(rules.keys) }
  public var restoringIDs: Set<Int> { owned.subtracting(activeIDs) }
  public private(set) var notice: String?
  public init(hardware: FanHardware, now: @escaping () -> ContinuousClock.Instant = { .now }) {
    self.hardware = hardware
    self.now = now
  }
  private func writeTarget(fan: Fan, rpm: Double, startingRPM: Double? = nil) throws {
    var startupFan = fan
    if let startingRPM { startupFan.current = min(fan.current, startingRPM) }
    let floor = try FanRPMPolicy.minimum(for: fan)
    let target = fanProtectionEnabled ? startup.target(for: startupFan, requested: rpm, at: now(), minimumRPM: floor) : rpm
    try hardware.setTarget(fan: fan, rpm: target)
    if fanProtectionEnabled { startup.confirmWrite(for: fan.id, at: now()) }
  }
  public func acknowledgeNotice() { notice = nil }

  @discardableResult public func restoreAll() -> Bool {
    rules.removeAll()
    startup.reset()
    restoreOrphans()
    return owned.isEmpty
  }
  private func restoreOrphans() {
    if rules.isEmpty, !owned.isEmpty {
      do {
        if try hardware.restoreSystemControl() {
          owned.removeAll()
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
            for: fan, sensors: snapshot.sensors)
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
  public func configure(id: Int, rule: FanPreset) throws {
    hardware.beginControlOperation()
    try configureWithinOperation(id: id, rule: rule)
  }
  private func configureWithinOperation(id: Int, rule: FanPreset, startingRPM: Double? = nil) throws {
    guard (0..<10).contains(id) else { throw FanError.invalid(L10n.t("Fan ID không hợp lệ.")) }
    // Read afresh at the privilege boundary; a cached snapshot cannot authorize writes.
    let snapshot = try hardware.snapshot()
    guard let fan = snapshot.fans.first(where: { $0.id == id }) else {
      throw FanError.invalid(L10n.t("Không tìm thấy quạt."))
    }
    if let rpm = try rule.target(for: fan, sensors: snapshot.sensors) {
      guard ControlSafety.permits(leaseAge: 0, sensors: snapshot.sensors) else {
        throw FanError.invalid(
          L10n.t("Cần cảm biến nhiệt hợp lệ dưới 90°C để điều khiển thủ công."))
      }
      owned.insert(id)
      do {
        try writeTarget(fan: fan, rpm: rpm, startingRPM: startingRPM)
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
      startup.reset(id)
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
        for: fan, sensors: snapshot.sensors)
    }
    var touched = Set<Int>()
    do {
      for id in ids.sorted() {
        touched.insert(id)
        // Opening Ftst for the first fan may spin another fan before its turn.
        // Preserve only its startup RPM baseline; target bounds and thermal safety
        // still use the fresh snapshot inside configureWithinOperation.
        try configureWithinOperation(id: id, rule: rule,
          startingRPM: snapshot.fans.first(where: { $0.id == id })?.current)
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
