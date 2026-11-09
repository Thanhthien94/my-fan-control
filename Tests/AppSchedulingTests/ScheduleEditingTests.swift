import FanCore
import Testing

@testable import MyFanControl

struct ScheduleEditingTests {
  @Test func editingKeepsTheSavedSnapshotWhenTheLibraryPresetChanged() {
    let saved = FanPreset(name: "Work", mode: .fixed, rpm: 2000)
    var updated = saved
    updated.rpm = 3000
    let choices = SchedulePresetChoice.make(library: [updated], saved: saved)
    #expect(choices.count == 2)
    #expect(choices.first(where: \.isSnapshot)?.preset == saved)
    #expect(Set(choices.map(\.id)).count == 2)
  }
}
