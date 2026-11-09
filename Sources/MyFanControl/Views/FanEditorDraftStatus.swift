import FanCore

/// Selection/save state is distinct from the mode currently confirmed on hardware.
enum FanEditorDraftStatus: Equatable {
  case automaticPending, automaticApplied, unsavedPreset, manualPending, manualApplied
  case authorizing, applying, restoring, invalid
  var isApplied: Bool { self == .automaticApplied || self == .manualApplied }
  var inProgress: Bool { self == .authorizing || self == .applying || self == .restoring }
  static func resolve(
    draft: FanPreset, saved: FanPreset?, applied: Bool,
    busy: Bool = false, authorizing: Bool = false, restoring: Bool = false, valid: Bool = true
  ) -> Self {
    if authorizing { return .authorizing }
    if busy { return .applying }
    if restoring { return .restoring }
    if !valid { return .invalid }
    if draft.mode == .automatic { return applied ? .automaticApplied : .automaticPending }
    if saved != draft { return .unsavedPreset }
    return applied ? .manualApplied : .manualPending
  }
}
