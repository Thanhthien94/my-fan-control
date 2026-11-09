import Foundation

/// Exact fan-key operations with a bounded Apple Silicon thermal-controller handoff.
/// Compatibility behavior informed by Stats (MIT); see THIRD_PARTY_NOTICES.md.
final class FanKeyController {
  static func isManual(mode: Double, gate: Double?) -> Bool { mode == 1 && (gate ?? 1) == 1 }
  let read: (String) throws -> Double
  let write: (String, Double) throws -> Void
  let wait: (TimeInterval) -> Void
  let cancelled: () -> Bool
  private(set) var forced = Set<Int>()
  private var ownsGate = false
  init(
    read: @escaping (String) throws -> Double, write: @escaping (String, Double) throws -> Void,
    wait: @escaping (TimeInterval) -> Void = { Thread.sleep(forTimeInterval: $0) },
    cancelled: @escaping () -> Bool = { false }
  ) {
    self.read = read
    self.write = write
    self.wait = wait
    self.cancelled = cancelled
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
    let key = modeKey(fan.id)
    // Check the complete control path before acquiring a global gate or recording ownership.
    let mask = key == nil ? try validatedMask() : nil
    _ = try read("F\(fan.id)Tg")
    forced.insert(fan.id)  // Keep cleanup ownership even if the handoff or first write fails.
    if let gate = try? read("Ftst") {
      guard gate == 0 || gate == 1 else {
        throw FanError.invalid(L10n.t("Không xác nhận được chế độ quạt."))
      }
      if gate == 0 {
        try retry("Ftst", 1, attempts: 100)
        ownsGate = true
        wait(3)
      } else {
        ownsGate = true
      }
      guard try read("Ftst") == 1 else {
        throw FanError.invalid(L10n.t("Không xác nhận được chế độ quạt."))
      }
    }
    if let key {
      try forcePair(key: key, fanID: fan.id, rpm: rpm, attempts: 300)
      return
    } else {
      let bits = mask ?? 0
      try retry("FS! ", Double(bits | (1 << fan.id)))
      guard try validatedMask() & (1 << fan.id) != 0 else {
        throw FanError.invalid(L10n.t("Không xác nhận được chế độ quạt."))
      }
    }
    try retry("F\(fan.id)Tg", rpm)
    guard abs(try read("F\(fan.id)Tg") - rpm) < 2 else {
      throw FanError.invalid(L10n.t("SMC không xác nhận RPM mục tiêu."))
    }
  }
  private func forcePair(key: String, fanID: Int, rpm: Double, attempts: Int) throws {
    var last: Error = FanError.invalid(L10n.t("Không xác nhận được chế độ quạt."))
    for i in 0..<attempts {
      if cancelled() { throw FanError.invalid(L10n.t("Đã hủy cấp quyền.")) }
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
  private func validatedMask() throws -> Int {
    let value = try read("FS! ")
    guard value.isFinite, value >= 0, value <= 65535, value.rounded(.towardZero) == value else {
      throw FanError.invalid(L10n.t("Không xác nhận được chế độ quạt."))
    }
    return Int(value)
  }
  private func confirmAutomatic(_ key: String) throws {
    for i in 0..<40 {
      let mode = try read(key)
      if mode == 0 || mode == 3 { return }
      if i + 1 < 40 { wait(0.05) }
    }
    throw FanError.invalid(L10n.t("Không xác nhận được chế độ quạt."))
  }
  func restore(_ id: Int) throws {
    guard (0..<10).contains(id) else { throw FanError.invalid(L10n.t("Fan ID không hợp lệ.")) }
    if (try? read("Ftst")) == 0 {
      forced.remove(id)
      if forced.isEmpty { ownsGate = false }
      return
    }
    if ownsGate, forced == [id] {
      _ = try returnSystemControl()
      return
    }
    let wasOurs = forced.contains(id)
    if let key = modeKey(id) {
      try retry(key, 0)
      try retry("F\(id)Tg", 0)
      // Gate-less firmware can acknowledge a write before applying it.
      // Never remove cleanup ownership until forced mode is actually gone.
      try confirmAutomatic(key)
    } else {
      let bits = try validatedMask()
      try retry("FS! ", Double(bits & ~(1 << id)))
      guard try validatedMask() & (1 << id) == 0 else {
        throw FanError.invalid(L10n.t("Không xác nhận được chế độ quạt."))
      }
    }
    forced.remove(id)
    do { if forced.isEmpty, ownsGate { _ = try returnSystemControl() } } catch {
      if wasOurs { forced.insert(id) }
      throw error
    }
  }
  @discardableResult func returnSystemControl(explicit: Bool = false) throws -> Bool {
    guard ownsGate || !forced.isEmpty || explicit else { return false }
    guard var gate = try? read("Ftst") else { return false }
    if gate == 0, !ownsGate, !explicit {
      forced.removeAll()
      return true
    }
    var ids = forced.sorted()
    if explicit {
      let count = try read("FNum")
      guard count >= 0, count <= 10 else {
        throw FanError.invalid(L10n.t("Số lượng quạt không hợp lệ."))
      }
      ids = Array(0..<Int(count))
    }
    do {
      if !ids.isEmpty, gate == 0 {
        try retry("Ftst", 1, attempts: 100)
        ownsGate = true
        wait(3)
        gate = 1
      }
      // Reset every owned mode and target before releasing the global gate. Leaving a
      // nonzero target behind can hold one fan at its last manual RPM after handback.
      for id in ids {
        if let key = modeKey(id) {
          try retry(key, 0, attempts: 40)
        } else {
          let bits = try validatedMask()
          try retry("FS! ", Double(bits & ~(1 << id)))
          guard try validatedMask() & (1 << id) == 0 else {
            throw FanError.invalid(L10n.t("Không xác nhận được chế độ quạt."))
          }
        }
        try retry("F\(id)Tg", 0, attempts: 40)
      }
      if gate != 0 { try retry("Ftst", 0, attempts: 40) }
      var released = false
      for i in 0..<40 {
        if try read("Ftst") == 0 {
          released = true
          break
        }
        if i + 1 < 40 { wait(0.05) }
      }
      guard released else { throw FanError.invalid(L10n.t("Không xác nhận được chế độ quạt.")) }
      forced.removeAll()
      ownsGate = false
      return true
    } catch {
      try? retry("Ftst", 0, attempts: 40)
      throw error
    }
  }
}
