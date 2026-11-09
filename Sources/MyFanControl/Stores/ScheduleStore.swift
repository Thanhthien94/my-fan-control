import FanCore
import Foundation
import Observation

struct ScheduledRun: Identifiable {
  var id: UUID
  var name: String
  var fanIDs: Set<Int>
  var preset: FanPreset
  var endsAt: Date
  var deadline: ContinuousClock.Instant
  var stopping = false
}
struct ScheduleEvent: Identifiable {
  var id = UUID()
  var date = Date()
  var key: String
  var name: String
}

@MainActor @Observable final class ScheduleStore {
  var items: [FanSchedule] = []
  var running: [UUID: ScheduledRun] = [:]
  var events: [ScheduleEvent] = []
  var error: String?
  private var lastTick: Date
  private let defaults: UserDefaults
  private var processing = false
  init(defaults: UserDefaults = .standard, lastTick: Date = Date()) {
    self.defaults = defaults
    self.lastTick = lastTick
    if let data = defaults.data(forKey: "schedules"),
      let saved = try? JSONDecoder().decode([FanSchedule].self, from: data)
    {
      items = saved.filter { (try? $0.validate()) != nil }
    }
    // Future schedules persist; elapsed one-off jobs never catch up at launch.
    for i in items.indices {
      if case .once(let date) = items[i].timing, date <= Date() { items[i].enabled = false }
    }
  }
  func save(_ schedule: FanSchedule) throws {
    try schedule.validate()
    guard items.count < 100 || items.contains(where: { $0.id == schedule.id }) else {
      throw FanError.invalid(L10n.t("schedule.limit"))
    }
    if case .once(let date) = schedule.timing, schedule.enabled, date <= Date() {
      throw FanError.invalid(L10n.t("schedule.past"))
    }
    if let conflict = items.first(where: { SchedulePlanner.conflicts(schedule, $0, now: Date()) }) {
      throw FanError.invalid(L10n.f("schedule.conflict", conflict.name))
    }
    if let i = items.firstIndex(where: { $0.id == schedule.id }) {
      items[i] = schedule
    } else {
      items.append(schedule)
    }
    error = nil
    persist()
  }
  func setEnabled(_ id: UUID, _ enabled: Bool) {
    guard var item = items.first(where: { $0.id == id }) else { return }
    item.enabled = enabled
    do { try save(item) } catch { self.error = error.localizedDescription }
  }
  func changeEnabled(_ id: UUID, _ enabled: Bool, store: FanStore) async {
    guard !processing, !store.busy else {
      error = L10n.t("operation.busy")
      return
    }
    if !enabled { await cancel(id, store: store) }
    setEnabled(id, enabled)
    if !enabled, running[id] != nil { error = L10n.t("schedule.restorePending") }
  }
  func replaceFromBackup(_ values: [FanSchedule]) {
    items = values
    persist()
  }
  private func persist() {
    if let data = try? JSONEncoder().encode(items) {
      defaults.set(data, forKey: "schedules")
    }
  }
  private func log(_ key: String, _ name: String) {
    events.insert(ScheduleEvent(key: key, name: name), at: 0)
    if events.count > 40 { events.removeLast(events.count - 40) }
  }
  func manualOverride(fanID: Int) {
    for id in Array(running.keys) {
      guard var run = running[id], run.fanIDs.remove(fanID) != nil else { continue }
      if run.fanIDs.isEmpty {
        running.removeValue(forKey: id)
        log("schedule.event.interrupted", run.name)
      } else {
        running[id] = run
      }
    }
  }
  func didRestoreAll() {
    for run in running.values { log("schedule.event.interrupted", run.name) }
    running.removeAll()
  }
  func cancel(_ id: UUID, store: FanStore) async {
    guard !processing, !store.busy else { return }
    processing = true
    defer { processing = false }
    running[id]?.deadline = .now
    running[id]?.stopping = true
    await finish(id, store: store, event: "schedule.event.canceled")
  }
  func delete(_ id: UUID, store: FanStore) async {
    await cancel(id, store: store)
    guard running[id] == nil else { return }
    items.removeAll { $0.id == id }
    persist()
  }
  private func finish(_ id: UUID, store: FanStore, event: String?) async {
    guard let run = running[id] else { return }
    for fanID in run.fanIDs.sorted() {
      if store.active[fanID]?.id != run.preset.id {
        running[id]?.fanIDs.remove(fanID)
      } else if await store.apply(
        FanPreset(name: L10n.t("Tự động"), mode: .automatic), to: fanID, scheduled: true)
      {
        running[id]?.fanIDs.remove(fanID)
      }
    }
    if running[id]?.fanIDs.isEmpty == true {
      running.removeValue(forKey: id)
      if let event { log(event, run.name) }
    }
  }
  func tick(store: FanStore, now: Date = Date(), instant: ContinuousClock.Instant = .now) async {
    guard !processing, !store.busy else { return }
    processing = true
    defer { processing = false }
    for run in Array(running.values) {
      if instant >= run.deadline {
        await finish(run.id, store: store, event: "schedule.event.finished")
      } else if run.fanIDs.allSatisfy({ store.active[$0]?.id != run.preset.id }) {
        running.removeValue(forKey: run.id)
        log("schedule.event.interrupted", run.name)
      }
    }
    guard now >= lastTick else { return }  // Avoid duplicate starts after a backwards wall-clock adjustment.
    let previous = lastTick
    lastTick = now
    for item in items where item.enabled {
      guard let fire = item.nextFire(after: previous), fire <= now else { continue }
      if case .once = item.timing, let i = items.firstIndex(where: { $0.id == item.id }) {
        items[i].enabled = false
        persist()
      }
      guard now.timeIntervalSince(previous) <= 60, now.timeIntervalSince(fire) < 60 else {
        log("schedule.event.missed", item.name)
        continue
      }
      guard store.helperEnabled else {
        log("schedule.event.noPermission", item.name)
        continue
      }
      guard !store.conflictingApp,
        item.fanIDs.allSatisfy({ id in
          store.fans.contains(where: { $0.id == id && !$0.manual }) && store.active[id] == nil
            && !store.controlled.contains(id)
        })
      else {
        log("schedule.event.conflict", item.name)
        continue
      }
      var applied = Set<Int>()
      for fanID in item.fanIDs.sorted() {
        if await store.apply(item.preset, to: fanID, scheduled: true) {
          applied.insert(fanID)
        } else {
          break
        }
      }
      if !applied.isEmpty {
        let endsAt = fire.addingTimeInterval(Double(item.durationMinutes) * 60)
        running[item.id] = ScheduledRun(
          id: item.id, name: item.name, fanIDs: applied, preset: item.preset, endsAt: endsAt,
          deadline: instant.advanced(by: .seconds(max(0, endsAt.timeIntervalSince(now)))))
      }
      if applied.count != item.fanIDs.count {
        log("schedule.event.failed", item.name)
        // Failed rollbacks must retry on the next poll, not at the planned finish time.
        running[item.id]?.deadline = instant
        await finish(item.id, store: store, event: nil)
      } else {
        log("schedule.event.started", item.name)
      }
    }
  }
}
