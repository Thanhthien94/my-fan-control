import Foundation

/// Soft start is based on monotonic elapsed time, not the number of helper requests.
struct FanStartupRamp {
  private struct Step { var rpm: Double; var time: ContinuousClock.Instant }
  private var steps = [Int: Step]()
  mutating func reset(_ id: Int? = nil) {
    if let id { steps.removeValue(forKey: id) } else { steps.removeAll() }
  }
  /// Handshake time before a confirmed write must not count as acceleration time.
  mutating func confirmWrite(for id: Int, at time: ContinuousClock.Instant) {
    steps[id]?.time = time
  }
  mutating func target(for fan: Fan, requested: Double, at time: ContinuousClock.Instant) -> Double {
    guard requested > 0 else { reset(fan.id); return requested }
    guard let previous = steps[fan.id] else {
      guard fan.current < 1000, requested > fan.current else { return requested }
      let first = min(requested, 1000, max(0, fan.current) + 200)
      steps[fan.id] = Step(rpm: first, time: time)
      return first
    }
    let duration = previous.time.duration(to: time).components
    let elapsed = max(0, min(2, Double(duration.seconds) + Double(duration.attoseconds) / 1e18))
    let rate = previous.rpm < 1000 ? 200.0 : 500.0
    let ceiling = previous.rpm < 1000 ? 1000.0 : fan.maximum
    let next = requested <= previous.rpm ? requested : min(requested, ceiling, previous.rpm + rate * elapsed)
    steps[fan.id] = Step(rpm: next, time: time)
    return next
  }
}
