import FanCore

/// Automatic control is an action, not a change to the saved manual preset.
enum FanEditorDraftStatus: Equatable {
  case automaticPending, automaticApplied, unsavedPreset, ready
  static func resolve(draft: FanPreset, saved: FanPreset?, applied: Bool) -> Self {
    if draft.mode == .automatic { return applied ? .automaticApplied : .automaticPending }
    return saved != nil && saved != draft ? .unsavedPreset : .ready
  }
}
