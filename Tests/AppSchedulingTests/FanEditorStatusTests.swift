import FanCore
import Testing

@testable import MyFanControl

@MainActor struct FanEditorStatusTests {
  @Test func successfulAutomaticApplyDoesNotShowUnsavedPresetWarning() async {
    let (store, _, _, _) = ScheduleExecutionTests().fixture(.now)
    let saved = FanPreset(name: "Work", mode: .fixed, rpm: 2000)
    store.save(saved)
    #expect(await store.activate(saved, fanIDs: [0, 1]))
    var draft = saved
    draft.mode = .automatic
    #expect(await store.activate(draft, fanIDs: [0, 1]))
    #expect(store.fans.allSatisfy { !$0.manual })
    #expect(FanEditorDraftStatus.resolve(draft: draft, saved: saved, applied: true) == .automaticApplied)
    #expect(store.presets == [saved])
  }
  @Test func selectingAutomaticBeforeApplyHasAnApplyHintInsteadOfSaveWarning() {
    let saved = FanPreset(name: "Work", mode: .fixed, rpm: 2000)
    var draft = saved
    draft.mode = .automatic
    #expect(FanEditorDraftStatus.resolve(draft: draft, saved: saved, applied: false) == .automaticPending)
  }
  @Test func editingManualPresetStillShowsUnsavedWarning() {
    let saved = FanPreset(name: "Work", mode: .fixed, rpm: 2000)
    var draft = saved
    draft.rpm = 2500
    #expect(FanEditorDraftStatus.resolve(draft: draft, saved: saved, applied: false) == .unsavedPreset)
    #expect(FanEditorDraftStatus.resolve(draft: saved, saved: saved, applied: true) == .ready)
  }
}
