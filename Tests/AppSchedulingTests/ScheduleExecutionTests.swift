import FanCore
import Foundation
import Testing

@testable import MyFanControl

actor HardwareFake: HardwareBackend {
  var policies = [Int: FanPreset]()
  var commands = [String]()
  var failFan: Int?
  var failedRestores = 0
  var online = true
  var cancelAuthorization = false
  var authorizationCount = 0
  var bootstrapFailure: String?
  var responseProtocol = 3
  func useOldProtocol() { responseProtocol = 2 }
  func requireAuthorization(cancel: Bool = false, failure: String? = nil) {
    online = false
    cancelAuthorization = cancel
    bootstrapFailure = failure
  }
  func failOneRestore() { failedRestores = 1 }
  func fail(on id: Int) { failFan = id }
  func read() -> Snapshot {
    Snapshot(
      fans: (0..<2).map { id in
        Fan(
          id: id, name: "Fan", current: 2000, minimum: 1000, maximum: 6000,
          manual: policies[id] != nil)
      },
      sensors: [Sensor(id: "test", name: "Sensor", celsius: 50)])
  }
  func send(_ request: HelperRequest) throws -> HelperResponse {
    guard online else { throw FanError.helper("Authorization required") }
    commands.append(request.command)
    if request.command == "configureGroup", let ids = request.fanIDs, let rule = request.preset {
      do {
        for id in ids {
          if id == failFan { throw FanError.invalid("Injected group failure") }
          if rule.mode == .automatic {
            policies.removeValue(forKey: id)
          } else {
            policies[id] = rule
          }
        }
      } catch {
        for id in ids { policies.removeValue(forKey: id) }
        throw error
      }
    }
    if request.command == "configure", let id = request.fanID, let rule = request.preset {
      if rule.mode == .automatic, failedRestores > 0 {
        failedRestores -= 1
        throw FanError.invalid("Injected restore failure")
      }
      if id == failFan, rule.mode != .automatic { throw FanError.invalid("Injected failure") }
      if rule.mode == .automatic { policies.removeValue(forKey: id) } else { policies[id] = rule }
    }
    if request.command == "automatic" || request.command == "shutdown" { policies = [:] }
    var response = HelperResponse(ok: true, controlled: policies.keys.sorted())
    response.protocolVersion = responseProtocol
    return response
  }
  func authorize() throws {
    authorizationCount += 1
    if cancelAuthorization { throw FanError.helper("Authorization canceled") }
    online = bootstrapFailure == nil
    responseProtocol = 3
  }
  func authorizationFailure() -> String? { bootstrapFailure }
  func authorizations() -> Int { authorizationCount }
  func ids() -> Set<Int> { Set(policies.keys) }
  func configurationCount() -> Int { commands.filter { $0 == "configure" }.count }
  func groupConfigurationCount() -> Int { commands.filter { $0 == "configureGroup" }.count }
}

@MainActor struct ScheduleExecutionTests {
  @Test func sharedManualControlUsesOneGroupRequest() async {
    let (store, hardware, _, _) = fixture(Date())
    let preset = FanPreset(name: "Shared", mode: .fixed, rpm: 2500)
    #expect(await store.applyToAll(preset))
    #expect(await hardware.ids() == [0, 1])
    #expect(await hardware.groupConfigurationCount() == 1)
    #expect(store.active[0]?.id == preset.id && store.active[1]?.id == preset.id)
  }
  func fixture(_ base: Date) -> (FanStore, HardwareFake, ScheduleStore, UserDefaults) {
    let defaults = UserDefaults(suiteName: "myfan-tests-\(UUID().uuidString)")!
    let hardware = HardwareFake()
    let schedules = ScheduleStore(defaults: defaults, lastTick: base)
    let store = FanStore(
      hardware: hardware, defaults: defaults, schedules: schedules, observeSleep: false)
    store.helperEnabled = true
    store.snapshot = Snapshot(
      fans: (0..<2).map { Fan(id: $0, name: "Fan", current: 2000, minimum: 1000, maximum: 6000) },
      sensors: [])
    return (store, hardware, schedules, defaults)
  }
  func job(_ base: Date, fans: [Int] = [0]) -> FanSchedule {
    FanSchedule(
      name: "Timer", fanIDs: fans, preset: FanPreset(name: "Fixed", mode: .fixed, rpm: 2500),
      durationMinutes: 1, timing: .once(base.addingTimeInterval(1)))
  }
  @Test func timerStartsOnceAndReturnsOnlyItsFanToAutomatic() async {
    let base = Date()
    let instant = ContinuousClock.now
    let (store, hardware, schedules, _) = fixture(base)
    let item = job(base)
    schedules.items = [item]
    await schedules.tick(store: store, now: base.addingTimeInterval(2), instant: instant)
    #expect(await hardware.ids() == [0])
    #expect(schedules.running.count == 1)
    await schedules.tick(
      store: store, now: base.addingTimeInterval(3), instant: instant.advanced(by: .seconds(1)))
    #expect(await hardware.configurationCount() == 1)
    await schedules.tick(
      store: store, now: base.addingTimeInterval(62), instant: instant.advanced(by: .seconds(60)))
    #expect(await hardware.ids().isEmpty)
    #expect(schedules.running.isEmpty)
  }
  @Test func manualOverrideCannotBeUndoneByAnOldTimer() async {
    let base = Date()
    let instant = ContinuousClock.now
    let (store, hardware, schedules, _) = fixture(base)
    schedules.items = [job(base)]
    await schedules.tick(store: store, now: base.addingTimeInterval(2), instant: instant)
    let manual = FanPreset(name: "Manual", mode: .fixed, rpm: 3000)
    #expect(await store.apply(manual, to: 0))
    #expect(schedules.running.isEmpty)
    await schedules.tick(
      store: store, now: base.addingTimeInterval(62), instant: instant.advanced(by: .seconds(60)))
    #expect(await hardware.ids() == [0])
    #expect(store.active[0]?.id == manual.id)
  }
  @Test func missedAndUnauthorizedJobsNeverWriteHardware() async {
    for authorized in [false, true] {
      let base = Date()
      let (store, hardware, schedules, _) = fixture(base)
      schedules.items = [job(base)]
      store.helperEnabled = authorized
      await schedules.tick(store: store, now: base.addingTimeInterval(authorized ? 120 : 2))
      #expect(await hardware.configurationCount() == 0)
      #expect(schedules.running.isEmpty)
      #expect(schedules.items[0].enabled == false)
    }
  }
  @Test func groupFailureRollsBackTheFanThatAlreadyStarted() async {
    let base = Date()
    let (store, hardware, schedules, _) = fixture(base)
    schedules.items = [job(base, fans: [0, 1])]
    await hardware.fail(on: 1)
    await schedules.tick(store: store, now: base.addingTimeInterval(2))
    #expect(await hardware.ids().isEmpty)
    #expect(schedules.running.isEmpty)
    #expect(schedules.events.filter { $0.key == "schedule.event.failed" }.count == 1)
  }
  @Test func cancelRestoresAndFutureSchedulesPersist() async throws {
    let base = Date()
    let (store, hardware, schedules, defaults) = fixture(base)
    let item = job(base)
    try schedules.save(item)
    #expect(ScheduleStore(defaults: defaults).items.count == 1)
    await schedules.tick(store: store, now: base.addingTimeInterval(2))
    await schedules.cancel(item.id, store: store)
    #expect(await hardware.ids().isEmpty)
    #expect(schedules.running.isEmpty)
  }
  @Test func canceledRestoreIsRetriedBeforeTheOriginalDeadline() async {
    let base = Date()
    let instant = ContinuousClock.now
    let (store, hardware, schedules, _) = fixture(base)
    let item = job(base)
    schedules.items = [item]
    await schedules.tick(store: store, now: base.addingTimeInterval(2), instant: instant)
    await hardware.failOneRestore()
    await schedules.cancel(item.id, store: store)
    #expect(schedules.running.count == 1)
    #expect(await hardware.ids() == [0])
    await schedules.tick(
      store: store, now: base.addingTimeInterval(3), instant: instant.advanced(by: .seconds(2)))
    #expect(schedules.running.isEmpty)
    #expect(await hardware.ids().isEmpty)
  }
  @Test func backwardWallClockCannotExtendAnActiveTimer() async {
    let base = Date()
    let instant = ContinuousClock.now
    let (store, hardware, schedules, _) = fixture(base)
    schedules.items = [job(base)]
    await schedules.tick(store: store, now: base.addingTimeInterval(2), instant: instant)
    await schedules.tick(
      store: store, now: base.addingTimeInterval(-3600), instant: instant.advanced(by: .seconds(60))
    )
    #expect(schedules.running.isEmpty)
    #expect(await hardware.ids().isEmpty)
  }
}
