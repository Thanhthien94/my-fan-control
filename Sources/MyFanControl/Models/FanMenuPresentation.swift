import FanCore

/// Detached menu values: a native tracking menu must not observe live telemetry rows.
struct FanMenuPresentation {
  var reading: Snapshot?
  var presets: [FanPreset]
  var helperEnabled: Bool
  var busy: Bool
  var fans: [Fan] { reading?.fans ?? [] }
  var hottest: Sensor? { reading?.sensors.max { $0.celsius < $1.celsius } }
  @MainActor init(_ store: FanStore) {
    reading = store.snapshot
    presets = store.presets
    helperEnabled = store.helperEnabled
    busy = store.busy
  }
}
