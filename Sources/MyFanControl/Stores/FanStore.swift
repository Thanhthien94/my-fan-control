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
  var authorizing = false
  private let feedbackNow: () -> ContinuousClock.Instant
  private var feedbackExpiry: ContinuousClock.Instant?
  private var feedbackExpected: [Int: FanPreset]?
  var active = [Int: FanPreset]()
  var controlled = Set<Int>()
  var restoring = Set<Int>()
  private var pendingPresetRestorations = [UUID: Set<Int>]()
  private(set) var minimumRPM: Double?
  private(set) var fanProtectionEnabled = true
  func effectiveMinimumRPM(for fan: Fan) -> Double {
    (try? FanRPMPolicy.minimum(for: fan, custom: minimumRPM, protection: fanProtectionEnabled)) ?? fan.minimum
  }
  var maximumMinimumRPM: Double { fans.map(\.maximum).min() ?? 20000 }
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
  @discardableResult func setFanProtection(_ enabled: Bool) async -> Bool {
    guard !busy, !schedules.isProcessing else { error = L10n.t("operation.busy"); return false }
    busy = true
    defer { busy = false }
    operationMessage = nil
    do {
      if helperEnabled {
        let result = try await hardware.send(HelperRequest("setFanProtection", fanProtectionEnabled: enabled))
        controlled = Set(result.controlled)
        restoring = Set(result.restoring ?? [])
        helperMessage = result.message
      } else if !active.isEmpty || !controlled.isEmpty || !restoring.isEmpty {
        throw FanError.helper(L10n.t("Chưa bật quyền điều khiển quạt."))
      }
      fanProtectionEnabled = enabled
      defaults.set(enabled, forKey: "fanProtectionEnabled")
      error = nil
      showOperation(L10n.t(enabled ? "protection.enabled" : "protection.disabled"))
      return true
    } catch {
      let message = error.localizedDescription
      if helperEnabled { await refresh() }
      self.error = message
      return false
    }
  }
  @discardableResult func setMinimumRPM(_ value: Double?) async -> Bool {
    guard !busy, !schedules.isProcessing else { error = L10n.t("operation.busy"); return false }
    if let value, !value.isFinite || value < 0 || value > maximumMinimumRPM {
      error = L10n.f("rpm.minimumInvalid", Int(maximumMinimumRPM))
      return false
    }
    busy = true
    defer { busy = false }
    operationMessage = nil
    do {
      if helperEnabled {
        let result = try await hardware.send(HelperRequest("setMinimumRPM", minimumRPM: value))
        controlled = Set(result.controlled)
        restoring = Set(result.restoring ?? [])
        helperMessage = result.message
      } else if !active.isEmpty || !controlled.isEmpty || !restoring.isEmpty {
        throw FanError.helper(L10n.t("Chưa bật quyền điều khiển quạt."))
      }
      minimumRPM = value
      if let value { defaults.set(value, forKey: "minimumRPM") }
      else { defaults.removeObject(forKey: "minimumRPM") }
      error = nil
      showOperation(L10n.t("rpm.minimumSaved"))
      return true
    } catch {
      let message = error.localizedDescription
      if helperEnabled { await refresh() }
      self.error = message
      return false
    }
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
    schedules: ScheduleStore? = nil, observeSleep: Bool = true,
    feedbackNow: @escaping () -> ContinuousClock.Instant = { .now }
  ) {
    self.feedbackNow = feedbackNow
    self.hardware = hardware
    self.defaults = defaults
    self.fanProtectionEnabled = defaults.object(forKey: "fanProtectionEnabled") as? Bool ?? true
    if let value = defaults.object(forKey: "minimumRPM") as? Double,
      value.isFinite, value >= 0, value <= 20000 { self.minimumRPM = value }
    self.schedules = schedules ?? ScheduleStore(defaults: defaults)
    if let data = defaults.data(forKey: "presets") {
      do {
        let saved = try JSONDecoder().decode([FanPreset].self, from: data)
        presets = saved.filter { (try? $0.validateDefinition()) != nil }
        if presets.count != saved.count {
          defaults.set(data, forKey: "invalidPresetsRecovery")
          error = L10n.t("backup.invalidSaved")
        }
      } catch {
        defaults.set(data, forKey: "invalidPresetsRecovery")
        presets = []
        self.error = L10n.t("backup.invalidSaved")
      }
    } else { presets = [] }
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
      let clock = ContinuousClock()
      while !Task.isCancelled {
        guard let self else { break }
        // Include read time in the one-second cadence; slow reads never queue catch-up polls.
        let nextRefresh = clock.now.advanced(by: .seconds(1))
        await self.refresh()
        try? await clock.sleep(until: nextRefresh)
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
      history = TemperatureHistory.retaining(history, asOf: reading.date)
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
        active = active.filter { controlled.contains($0.key) }
      } catch {
        helperEnabled = false
        controlled = []
        active = [:]
        self.error = error.localizedDescription
      }
    }
    reconcileOperationFeedback()
    await schedules.tick(store: self)
  }
  func enable() async {
    guard !busy else { return }
    guard !conflictingApp else {
      error = L10n.t("Hãy thoát Macs Fan Control trước khi bật điều khiển trong app này.")
      return
    }
    busy = true
    authorizing = true
    defer { busy = false; authorizing = false }
    do {
      // Reuse an already-running root helper before asking macOS for authorization.
      if (try? await hardware.send(HelperRequest("status")))?.protocolVersion
        != HelperResponse.currentProtocolVersion
      {
        try await hardware.authorize()
      }
      var connected = false
      for _ in 0..<600 {
        if let failure = await hardware.authorizationFailure() { throw FanError.helper(failure) }
        if let result = try? await hardware.send(HelperRequest("status")),
          result.protocolVersion == HelperResponse.currentProtocolVersion
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
      let result = try await hardware.send(HelperRequest("configure", fanID: id, preset: rule, minimumRPM: minimumRPM, fanProtectionEnabled: fanProtectionEnabled))
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
    let ids = controlled.union(active.keys)
    operationMessage = nil
    do {
      _ = try await hardware.send(HelperRequest("automatic"))
      active = [:]
      controlled = []
      helperMessage = nil
      restoring = []
      error = nil
      let automatic = FanPreset(name: L10n.t("Tự động"), mode: .automatic)
      showOperation(L10n.t("preset.alreadyAuto"), expecting: Dictionary(uniqueKeysWithValues: ids.map { ($0, automatic) }))
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
          for: fan, sensors: snapshot.sensors, minimumRPM: minimumRPM, fanProtectionEnabled: fanProtectionEnabled)
      }
      let result = try await hardware.send(
        HelperRequest("configureGroup", fanIDs: snapshot.fans.map(\.id), preset: rule, minimumRPM: minimumRPM, fanProtectionEnabled: fanProtectionEnabled))
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
    do { try saved.validateDefinition() } catch {
      self.error = error.localizedDescription
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
      showOperation(L10n.f("preset.saved", saved.name))
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
          for: fan, sensors: reading.sensors, minimumRPM: minimumRPM, fanProtectionEnabled: fanProtectionEnabled)
      }
      if rule.mode == .automatic, !helperEnabled,
        reading.fans.filter({ fanIDs.contains($0.id) }).allSatisfy({ !$0.manual })
      {
        showControlSuccess(rule, fanIDs: fanIDs)
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
      showControlSuccess(rule, fanIDs: fanIDs)
    } else if error == nil {
      error = helperMessage ?? L10n.t("preset.notActive")
    }
    return success
  }
  private func showOperation(_ message: String, expecting: [Int: FanPreset]? = nil) {
    operationMessage = message
    feedbackExpected = expecting
    feedbackExpiry = feedbackNow().advanced(by: .seconds(6))
  }
  private func showControlSuccess(_ rule: FanPreset, fanIDs: [Int]) {
    let scope = fanIDs.map { id in fans.first(where: { $0.id == id })?.name ?? L10n.f("fan.name", id + 1) }.joined(separator: ", ")
    let message: String
    switch rule.mode {
    case .automatic: message = L10n.t("preset.alreadyAuto")
    case .fixed:
      let targets = fans.filter { fanIDs.contains($0.id) }.map {
        "\($0.name): \(Int(max(rule.rpm, effectiveMinimumRPM(for: $0)))) RPM"
      }.joined(separator: ", ")
      message = L10n.f("mode.fixedAppliedTargets", targets, rule.name)
    case .sensor: message = L10n.f("mode.sensorApplied", rule.sensorTitle, scope, rule.name)
    }
    showOperation(message, expecting: Dictionary(uniqueKeysWithValues: fanIDs.map { ($0, rule) }))
  }
  private func reconcileOperationFeedback() {
    guard operationMessage != nil else { return }
    let expired = feedbackExpiry.map { feedbackNow() >= $0 } ?? false
    let changed = feedbackExpected.map { expected in
      !expected.allSatisfy { id, rule in
        guard let fan = fans.first(where: { $0.id == id }), !restoring.contains(id) else { return false }
        if rule.mode == .automatic { return !fan.manual && !controlled.contains(id) }
        return helperEnabled && fan.manual && controlled.contains(id) && active[id] == rule
      }
    } ?? false
    if expired || changed {
      operationMessage = nil
      feedbackExpiry = nil
      feedbackExpected = nil
    }
  }
  func exportBackup() throws -> Data {
    try ConfigurationBackup(presets: presets, schedules: schedules.items).encoded()
  }
  func backupPlan(_ data: Data) throws -> ConfigurationBackup {
    try ConfigurationBackup.decode(data).merge(presets: presets, schedules: schedules.items)
  }
  func importBackup(_ data: Data) throws {
    guard !busy else { throw FanError.invalid(L10n.t("operation.busy")) }
    let plan = try backupPlan(data)
    let encoded = try JSONEncoder().encode(plan.presets)
    defaults.set(encoded, forKey: "presets")
    presets = plan.presets
    schedules.replaceFromBackup(plan.schedules)
  }
  func diagnosticsData() async throws -> Data {
    struct Report: Encodable {
      let appVersion: String
      let build: String
      let revision: String
      let macOS: String
      let hardware: CompatibilityReport
    }
    let meta = AppMetadata()
    let report = try await hardware.diagnostics()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(Report(appVersion: meta.version, build: meta.build,
      revision: meta.revision, macOS: ProcessInfo.processInfo.operatingSystemVersionString, hardware: report))
  }
  @discardableResult func deletePreset(_ id: UUID) async -> Bool {
    guard !busy, !schedules.isProcessing else {
      error = L10n.t("operation.busy")
      return false
    }
    guard let preset = presets.first(where: { $0.id == id }) else { return false }
    // Match the stable identity: a saved definition may differ from its running copy.
    let pending = (pendingPresetRestorations[id] ?? []).filter {
      active[$0] == nil || active[$0]?.id == id
    }
    let affected = Set(active.filter { $0.value.id == id }.keys).union(pending).sorted()
    pendingPresetRestorations[id] = Set(affected)
    operationMessage = nil
    error = nil
    busy = true
    defer { busy = false }
    var failure: String?
    let automatic = FanPreset(name: L10n.t("Tự động"), mode: .automatic)
    // Keep the operation locked across awaits so schedules cannot reclaim restored fans.
    for fanID in affected {
      do {
        guard helperEnabled else {
          throw FanError.helper(L10n.t("Chưa bật quyền điều khiển quạt."))
        }
        let result = try await hardware.send(
          HelperRequest("configure", fanID: fanID, preset: automatic))
        controlled = Set(result.controlled)
        restoring = Set(result.restoring ?? [])
        helperMessage = result.message
        guard !controlled.contains(fanID), !restoring.contains(fanID) else {
          throw FanError.helper(L10n.t("schedule.restorePending"))
        }
        active.removeValue(forKey: fanID)
        pendingPresetRestorations[id]?.remove(fanID)
        schedules.manualOverride(fanID: fanID)
      } catch {
        // Attempt the other affected fans too; retain the preset if any restore fails.
        if failure == nil { failure = error.localizedDescription }
      }
    }
    if let failure {
      error = L10n.f("preset.deleteRestoreFailed", failure)
      return false
    }
    pendingPresetRestorations.removeValue(forKey: id)
    presets.removeAll { $0.id == id }
    persist()
    if !affected.isEmpty { await refresh() }
    showOperation(L10n.f(affected.isEmpty ? "preset.deleted" : "preset.deletedRestored", preset.name))
    return true
  }
  private func persist() {
    if let data = try? JSONEncoder().encode(presets) {
      defaults.set(data, forKey: "presets")
    }
  }
}
