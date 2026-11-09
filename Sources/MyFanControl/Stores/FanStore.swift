import AppKit
import FanCore
import Observation

struct TemperaturePoint: Identifiable {
  var id = UUID()
  var date: Date
  var temperature: Double
}

@MainActor @Observable final class FanStore {
  let schedules: ScheduleStore
  var snapshot: Snapshot?
  var error: String?
  var telemetryError: String?
  var operationMessage: String?
  var helperEnabled = false
  var busy = false
  var active = [Int: FanPreset]()
  var controlled = Set<Int>()
  var restoring = Set<Int>()
  var presets: [FanPreset]
  var history = [TemperaturePoint]()
  var selectedFan = 0
  var lastRead: Date?
  var helperMessage: String?
  private let hardware: any HardwareBackend
  private let defaults: UserDefaults
  private var loop: Task<Void, Never>?
  private var sleepObserver: NSObjectProtocol?
  var hottest: Sensor? { snapshot?.sensors.max(by: { $0.celsius < $1.celsius }) }
  var fans: [Fan] { snapshot?.fans ?? [] }
  var sensors: [Sensor] { snapshot?.sensors ?? [] }
  var preferredSensorID: String {
    let valid = sensors.filter {
      $0.celsius >= 10 && $0.celsius < 125 && SensorCatalog.lookup($0.id).known
    }
    return valid.filter { SensorCatalog.lookup($0.id).component == .cpu }.max(by: {
      $0.celsius < $1.celsius
    })?.id
      ?? valid.max(by: { $0.celsius < $1.celsius })?.id ?? ""
  }
  func uniquePresetName(_ base: String) -> String {
    var name = base
    var index = 2
    while presets.contains(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame })
    {
      name = "\(base) \(index)"
      index += 1
    }
    return name
  }
  var conflictingApp: Bool {
    NSWorkspace.shared.runningApplications.contains {
      $0.bundleIdentifier == "com.crystalidea.macsfancontrol"
        || $0.localizedName == "Macs Fan Control"
    }
  }
  init(
    hardware: any HardwareBackend = HardwareService(), defaults: UserDefaults = .standard,
    schedules: ScheduleStore? = nil, observeSleep: Bool = true
  ) {
    self.hardware = hardware
    self.defaults = defaults
    self.schedules = schedules ?? ScheduleStore(defaults: defaults)
    if let data = defaults.data(forKey: "presets"),
      let saved = try? JSONDecoder().decode([FanPreset].self, from: data)
    {
      presets = saved
    } else {
      presets = []
    }
    if observeSleep {
      sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
      ) { [weak self] _ in
        Task { @MainActor in await self?.restoreAll() }
      }
    }
  }
  func start() {
    guard loop == nil else { return }
    loop = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { break }
        await self.refresh()
        try? await Task.sleep(for: .seconds(2))
      }
    }
  }
  func refresh() async {
    do {
      let reading = try await hardware.read()
      snapshot = reading
      lastRead = reading.date
      telemetryError = nil
      if let hottest {
        history.append(TemperaturePoint(date: reading.date, temperature: hottest.celsius))
      }
      if history.count > 300 { history.removeFirst(history.count - 300) }
      if !fans.contains(where: { $0.id == selectedFan }) { selectedFan = fans.first?.id ?? 0 }
    } catch {
      self.telemetryError = error.localizedDescription
      snapshot = nil
      if helperEnabled { await restoreAll() }
    }
    if helperEnabled {
      do {
        let response = try await hardware.send(HelperRequest("status"))
        controlled = Set(response.controlled)
        restoring = Set(response.restoring ?? [])
        helperMessage = response.message
        if !Set(active.keys).isSubset(of: controlled), response.message != nil {
          operationMessage = nil
        }
        active = active.filter { controlled.contains($0.key) }
      } catch {
        helperEnabled = false
        controlled = []
        active = [:]
        self.error = error.localizedDescription
      }
    }
    await schedules.tick(store: self)
  }
  func enable() async {
    guard !busy else { return }
    guard !conflictingApp else {
      error = L10n.t("Hãy thoát Macs Fan Control trước khi bật điều khiển trong app này.")
      return
    }
    busy = true
    defer { busy = false }
    do {
      // Reuse an already-running root helper before asking macOS for authorization.
      if (try? await hardware.send(HelperRequest("status")))?.protocolVersion != 3 {
        try await hardware.authorize()
      }
      var connected = false
      for _ in 0..<600 {
        if let failure = await hardware.authorizationFailure() { throw FanError.helper(failure) }
        if let result = try? await hardware.send(HelperRequest("status")),
          result.protocolVersion == 3
        {
          controlled = Set(result.controlled)
          connected = true
          break
        }
        try await Task.sleep(for: .milliseconds(200))
      }
      guard connected else {
        await hardware.cancelAuthorization()
        throw FanError.helper(L10n.t("preset.permissionTimeout"))
      }
      helperEnabled = true
      error = nil
    } catch { self.error = error.localizedDescription }
  }
  @discardableResult func apply(_ rule: FanPreset, to id: Int, scheduled: Bool = false) async
    -> Bool
  {
    guard helperEnabled, !busy else { return false }
    guard !conflictingApp else {
      error = L10n.t("Hãy thoát Macs Fan Control trước khi áp dụng.")
      return false
    }
    guard let snapshot, Date().timeIntervalSince(snapshot.date) < 5 else {
      error = L10n.t("Dữ liệu phần cứng đã cũ. Hãy đợi cập nhật.")
      return false
    }
    busy = true
    defer { busy = false }
    do {
      let result = try await hardware.send(HelperRequest("configure", fanID: id, preset: rule))
      controlled = Set(result.controlled)
      if controlled.contains(id) { active[id] = rule } else { active.removeValue(forKey: id) }
      helperMessage = result.message
      error = nil
      if !scheduled { schedules.manualOverride(fanID: id) }
    } catch {
      self.error = error.localizedDescription
      return false
    }
    await refresh()
    return rule.mode == .automatic ? !controlled.contains(id) : active[id]?.id == rule.id
  }
  func restoreAll() async {
    guard helperEnabled else { return }
    do {
      _ = try await hardware.send(HelperRequest("automatic"))
      active = [:]
      controlled = []
      helperMessage = nil
      restoring = []
      error = nil
      operationMessage = L10n.t("preset.alreadyAuto")
      schedules.didRestoreAll()
    } catch { self.error = error.localizedDescription }
  }
  @discardableResult func applyToAll(_ rule: FanPreset) async -> Bool {
    guard helperEnabled, !busy else { return false }
    guard !conflictingApp else {
      error = L10n.t("Hãy thoát Macs Fan Control trước khi áp dụng.")
      return false
    }
    guard let snapshot, !snapshot.fans.isEmpty, Date().timeIntervalSince(snapshot.date) < 5 else {
      error = L10n.t("Dữ liệu phần cứng đã cũ. Hãy đợi cập nhật.")
      return false
    }
    busy = true
    defer { busy = false }
    do {
      for fan in snapshot.fans {
        _ = try rule.target(
          for: fan, temperature: snapshot.sensors.first(where: { $0.id == rule.sensor })?.celsius)
      }
      let result = try await hardware.send(
        HelperRequest("configureGroup", fanIDs: snapshot.fans.map(\.id), preset: rule))
      controlled = Set(result.controlled)
      for fan in snapshot.fans {
        if controlled.contains(fan.id) {
          active[fan.id] = rule
        } else {
          active.removeValue(forKey: fan.id)
        }
        schedules.manualOverride(fanID: fan.id)
      }
      helperMessage = result.message
      error = nil
      await refresh()
      return snapshot.fans.allSatisfy { fan in
        rule.mode == .automatic ? !controlled.contains(fan.id) : active[fan.id] == rule
      }
    } catch {
      let message = error.localizedDescription
      await refresh()
      self.error = message
      return false
    }
  }
  func shutdown() async {
    if helperEnabled {
      do {
        _ = try await hardware.send(HelperRequest("shutdown"))
        helperEnabled = false
        active = [:]
        controlled = []
        restoring = []
        error = nil
        operationMessage = nil
        schedules.didRestoreAll()
      } catch { self.error = error.localizedDescription }
    } else {
      await hardware.cancelAuthorization()
    }
  }
  @discardableResult func save(_ rule: FanPreset) -> FanPreset? {
    var saved = rule
    saved.name = saved.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !saved.name.isEmpty, saved.name.count <= 80 else {
      error = L10n.t("preset.nameRequired")
      return nil
    }
    let original = presets.first(where: { $0.id == saved.id })
    guard
      original?.name == saved.name
        || !presets.contains(where: {
          $0.id != saved.id && $0.name.localizedCaseInsensitiveCompare(saved.name) == .orderedSame
        })
    else {
      error = L10n.t("preset.duplicateName")
      return nil
    }
    guard presets.count < 50 || presets.contains(where: { $0.id == saved.id }) else {
      error = L10n.t("preset.limit")
      return nil
    }
    var updated = presets
    if let index = updated.firstIndex(where: { $0.id == saved.id }) {
      updated[index] = saved
    } else {
      updated.append(saved)
    }
    do {
      let data = try JSONEncoder().encode(updated)
      defaults.set(data, forKey: "presets")
      presets = updated
      error = nil
      operationMessage = L10n.f("preset.saved", saved.name)
      return saved
    } catch {
      self.error = error.localizedDescription
      return nil
    }
  }
  /// Explicit user action may authorize; background schedules never call this method.
  @discardableResult func activate(_ rule: FanPreset, fanIDs: [Int]) async -> Bool {
    guard !busy, !fanIDs.isEmpty, Set(fanIDs).count == fanIDs.count else { return false }
    operationMessage = nil
    error = nil
    do {
      let reading = try await hardware.read()
      snapshot = reading
      lastRead = reading.date
      guard fanIDs.count == 1 || Set(fanIDs) == Set(reading.fans.map(\.id)) else {
        throw FanError.invalid(L10n.t("group.invalid"))
      }
      for id in fanIDs {
        guard let fan = reading.fans.first(where: { $0.id == id }) else {
          throw FanError.invalid(L10n.t("Không tìm thấy quạt."))
        }
        _ = try rule.target(
          for: fan, temperature: reading.sensors.first(where: { $0.id == rule.sensor })?.celsius)
      }
      if rule.mode == .automatic, !helperEnabled,
        reading.fans.filter({ fanIDs.contains($0.id) }).allSatisfy({ !$0.manual })
      {
        operationMessage = L10n.t("preset.alreadyAuto")
        return true
      }
    } catch {
      self.error = error.localizedDescription
      return false
    }
    if !helperEnabled { await enable() }
    guard helperEnabled else { return false }
    // Authorization can take minutes; never apply against the snapshot from before the prompt.
    await refresh()
    let success: Bool
    if fanIDs.count == 1 {
      success = await apply(rule, to: fanIDs[0])
    } else {
      success = await applyToAll(rule)
    }
    if success {
      operationMessage = L10n.f("preset.applied", rule.name)
    } else if error == nil {
      error = helperMessage ?? L10n.t("preset.notActive")
    }
    return success
  }
  func deletePreset(_ id: UUID) {
    let name = presets.first(where: { $0.id == id })?.name ?? ""
    presets.removeAll { $0.id == id }
    persist()
    error = nil
    operationMessage = L10n.f("preset.deleted", name)
  }
  private func persist() {
    if let data = try? JSONEncoder().encode(presets) {
      defaults.set(data, forKey: "presets")
    }
  }
}
