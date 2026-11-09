import Foundation

/// Exact fan-key operations with a bounded Apple Silicon thermal-controller handoff.
/// Compatibility behavior informed by Stats (MIT); see THIRD_PARTY_NOTICES.md.
final class FanKeyController {
  static func isManual(mode: Double, gate: Double?) -> Bool { mode == 1 && (gate ?? 1) == 1 }
  let read: (String) throws -> Double
  let write: (String, Double) throws -> Void
  let wait: (TimeInterval) -> Void
  private(set) var forced = Set<Int>()
  private var ownsGate = false
  init(
    read: @escaping (String) throws -> Double, write: @escaping (String, Double) throws -> Void,
    wait: @escaping (TimeInterval) -> Void = { Thread.sleep(forTimeInterval: $0) }
  ) {
    self.read = read
    self.write = write
    self.wait = wait
  }
  func modeKey(_ id: Int) -> String? {
    if (try? read("F\(id)md")) != nil { return "F\(id)md" }
    if (try? read("F\(id)Md")) != nil { return "F\(id)Md" }
    return nil
  }
  private func retry(_ key: String, _ value: Double, attempts: Int = 10, delay: TimeInterval = 0.05)
    throws
  {
    var last: Error = FanError.invalid("SMC write failed")
    for i in 0..<attempts {
      do {
        try write(key, value)
        return
      } catch {
        last = error
        if i + 1 < attempts { wait(delay) }
      }
    }
    throw last
  }
  func setTarget(fan: Fan, rpm: Double) throws {
    guard (0..<10).contains(fan.id), rpm.isFinite, rpm >= fan.minimum, rpm <= fan.maximum else {
      throw FanError.invalid(L10n.t("RPM nằm ngoài giới hạn phần cứng."))
    }
    forced.insert(fan.id)  // Keep cleanup ownership even if the handoff or first write fails.
    if let gate = try? read("Ftst") {
      guard gate == 0 || gate == 1 else {
        throw FanError.invalid(L10n.t("Không xác nhận được chế độ quạt."))
      }
      if gate == 0 {
        try retry("Ftst", 1, attempts: 40)
        ownsGate = true
        wait(3)
      } else {
        ownsGate = true
      }
      guard try read("Ftst") == 1 else {
        throw FanError.invalid(L10n.t("Không xác nhận được chế độ quạt."))
      }
    }
    if let key = modeKey(fan.id) {
      try forcePair(key: key, fanID: fan.id, rpm: rpm, attempts: 20)
      return
    } else {
      let bits = Int(try read("FS! "))
      try retry("FS! ", Double(bits | (1 << fan.id)))
    }
    try retry("F\(fan.id)Tg", rpm)
    guard abs(try read("F\(fan.id)Tg") - rpm) < 2 else {
      throw FanError.invalid(L10n.t("SMC không xác nhận RPM mục tiêu."))
    }
  }
  private func forcePair(key: String, fanID: Int, rpm: Double, attempts: Int) throws {
    var last: Error = FanError.invalid(L10n.t("Không xác nhận được chế độ quạt."))
    for i in 0..<attempts {
      do {
        // Some firmware drops forced mode while target is zero. Write the bounded target
        // immediately after mode, then verify the pair instead of checking in between.
        try write(key, 1)
        try write("F\(fanID)Tg", rpm)
        if try read(key) == 1, abs(try read("F\(fanID)Tg") - rpm) < 2 { return }
      } catch { last = error }
      if i + 1 < attempts { wait(0.1) }
    }
    throw last
  }
  func restore(_ id: Int) throws {
    guard (0..<10).contains(id) else { throw FanError.invalid(L10n.t("Fan ID không hợp lệ.")) }
    if (try? read("Ftst")) == 0 {
      // With the gate released, mode/target belong to thermalmonitord. It can use mode 1
      // internally too; touching those keys would fight the system controller.
      forced.remove(id)
      if forced.isEmpty { ownsGate = false }
      return
    }
    let wasOurs = forced.contains(id)
    if let key = modeKey(id) {
      let mode = try read(key)
      guard mode == 0 || mode == 1 || mode == 3 else {
        throw FanError.invalid(L10n.t("Không xác nhận được chế độ quạt."))
      }
      if mode != 0 {
        try retry(key, 0)
        try retry("F\(id)Tg", 0)
      }
      guard try read(key) != 1 else {
        throw FanError.invalid(L10n.t("Không xác nhận được chế độ quạt."))
      }
    } else {
      let bits = Int(try read("FS! "))
      try retry("FS! ", Double(bits & ~(1 << id)))
    }
    forced.remove(id)
    do {
      if forced.isEmpty, ownsGate {
        try retry("Ftst", 0, attempts: 40)
        ownsGate = false
      } else if forced.isEmpty, (try? read("Ftst")) == 1 {
        let count = try read("FNum")
        guard count >= 0, count <= 10 else {
          throw FanError.invalid(L10n.t("Số lượng quạt không hợp lệ."))
        }
        let manual = try (0..<Int(count)).contains { fan in
          guard let key = modeKey(fan) else { return false }
          return try read(key) == 1
        }
        if !manual { try retry("Ftst", 0, attempts: 40) }
      }
    } catch {
      if wasOurs { forced.insert(id) }
      throw error
    }
  }
}
