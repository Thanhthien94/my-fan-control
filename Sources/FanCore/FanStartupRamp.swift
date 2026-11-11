import Foundation

/// Protected increases begin at the hardware/effective floor or current running RPM.
/// Reductions are immediate; request frequency cannot accelerate monotonic slew limits.
struct FanStartupRamp {
  private struct Step { var rpm: Double; var time: ContinuousClock.Instant }
  private var steps = [Int: Step]()
  mutating func reset(_ id: Int? = nil) {
    if let id { steps.removeValue(forKey: id) } else { steps.removeAll() }
  }
  mutating func confirmWrite(for id: Int, at time: ContinuousClock.Instant) {
    steps[id]?.time = time
  }
  mutating func target(for fan: Fan, requested: Double, at time: ContinuousClock.Instant, minimumRPM: Double = 0) -> Double {
    let goal = max(minimumRPM, requested)
    guard goal > 0 else { reset(fan.id); return goal }
    guard let previous = steps[fan.id] else {
      let first = min(goal, max(minimumRPM, fan.current))
      steps[fan.id] = Step(rpm: first, time: time)
      return first
    }
    let duration = previous.time.duration(to: time).components
    let elapsed = max(0, min(2, Double(duration.seconds) + Double(duration.attoseconds) / 1e18))
    let next = max(minimumRPM, goal <= previous.rpm ? goal : min(goal, previous.rpm + 500 * elapsed))
    steps[fan.id] = Step(rpm: next, time: time)
    return next
  }
}
