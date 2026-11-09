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
  var helperEnabled = false
  var busy = false
  var active = [Int: FanPreset]()
  var controlled = Set<Int>()
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
      error = nil
      if let hottest {
        history.append(TemperaturePoint(date: reading.date, temperature: hottest.celsius))
      }
      if history.count > 300 { history.removeFirst(history.count - 300) }
      if !fans.contains(where: { $0.id == selectedFan }) { selectedFan = fans.first?.id ?? 0 }
    } catch {
      self.error = error.localizedDescription
      snapshot = nil
      if helperEnabled { await restoreAll() }
    }
    if helperEnabled {
      do {
        let response = try await hardware.send(HelperRequest("status"))
        controlled = Set(response.controlled)
        helperMessage = response.message
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
      if (try? await hardware.send(HelperRequest("status"))) == nil {
        try await hardware.authorize()
      }
      var connected = false
      for _ in 0..<15 {
        if let result = try? await hardware.send(HelperRequest("status")) {
          controlled = Set(result.controlled)
          connected = true
          break
        }
        try await Task.sleep(for: .milliseconds(200))
      }
      guard connected else {
        throw FanError.helper(
          L10n.t(
            "Helper chưa kết nối. Nếu còn socket từ một phiên bị crash, xem README để phục hồi."))
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
      schedules.didRestoreAll()
    } catch { self.error = error.localizedDescription }
  }
  func shutdown() async {
    if helperEnabled {
      do {
        _ = try await hardware.send(HelperRequest("shutdown"))
        helperEnabled = false
        active = [:]
        controlled = []
        schedules.didRestoreAll()
      } catch { self.error = error.localizedDescription }
    }
  }
  func save(_ rule: FanPreset) {
    presets.append(rule)
    persist()
  }
  func deletePreset(_ id: UUID) {
    presets.removeAll { $0.id == id }
    persist()
  }
  private func persist() {
    if let data = try? JSONEncoder().encode(presets) {
      defaults.set(data, forKey: "presets")
    }
  }
}
