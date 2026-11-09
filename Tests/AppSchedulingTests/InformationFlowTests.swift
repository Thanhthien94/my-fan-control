import Foundation
import FanCore
import Testing

@testable import MyFanControl

@MainActor struct InformationFlowTests {
  @Test func metadataPreservesFullPreviewVersionAndBuild() {
    let revision = String(repeating: "a", count: 40)
    let meta = AppMetadata(info: ["MFCReleaseLabel": "0.3.0-preview.1", "CFBundleVersion": "31", "MFCSourceRevision": revision])
    #expect(meta.version == "0.3.0-preview.1" && meta.build == "31")
    #expect(meta.sourceURL.absoluteString.hasSuffix(revision))
    let invalid = AppMetadata(info: ["MFCSourceRevision": "../../malicious"])
    #expect(invalid.sourceURL.absoluteString.hasSuffix("/main"))
  }
  @Test func importingConfigurationNeverAppliesFansOrOverwritesExistingPresets() async throws {
    let (store, hardware, schedules, defaults) = ScheduleExecutionTests().fixture(Date())
    let existing = FanPreset(name: "Existing", mode: .fixed, rpm: 2000)
    store.save(existing)
    let incoming = FanPreset(name: "Import", mode: .fixed, rpm: 2500)
    let job = FanSchedule(name: "Job", fanIDs: [0], preset: incoming, durationMinutes: 5,
      timing: .weekly(days: [2], hour: 9, minute: 0))
    let data = try ConfigurationBackup(presets: [incoming], schedules: [job]).encoded()
    try store.importBackup(data)
    #expect(store.presets.first == existing && store.presets.count == 2)
    #expect(schedules.items.count == 1 && !schedules.items[0].enabled)
    #expect(await hardware.ids().isEmpty)
    let reopened = FanStore(hardware: hardware, defaults: defaults, observeSleep: false)
    #expect(reopened.presets.count == 2 && !reopened.schedules.items[0].enabled)
    let before = store.presets
    #expect(throws: (any Error).self) { try store.importBackup(Data("invalid".utf8)) }
    #expect(store.presets == before)
  }
}
