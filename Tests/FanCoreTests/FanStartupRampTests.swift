import Testing
@testable import FanCore

struct FanStartupRampTests {
  let fan = Fan(id: 0, name: "Fan", current: 0, minimum: 1200, maximum: 6000)
  @Test func coldStartUsesMonotonicSmallStepsAndNeverJumpsAt1000() {
    var ramp = FanStartupRamp()
    var time = ContinuousClock.now
    #expect(ramp.target(for: fan, requested: 5000, at: time) == 200)
    #expect(ramp.target(for: fan, requested: 5000, at: time) == 200)
    for expected in [400.0, 600, 800, 1000, 1500, 2000] {
      time = time.advanced(by: .seconds(1))
      #expect(ramp.target(for: fan, requested: 5000, at: time) == expected)
    }
  }
  @Test func reductionIsImmediateAndLongPauseCannotCauseCatchUpJump() {
    var ramp = FanStartupRamp()
    let time = ContinuousClock.now
    #expect(ramp.target(for: fan, requested: 5000, at: time) == 200)
    #expect(ramp.target(for: fan, requested: 5000, at: time.advanced(by: .seconds(30))) == 600)
    #expect(ramp.target(for: fan, requested: 100, at: time.advanced(by: .seconds(31))) == 100)
    #expect(ramp.target(for: fan, requested: 0, at: time.advanced(by: .seconds(32))) == 0)
  }
  @Test func spinningFanAndIndependentFanStateArePreserved() {
    var ramp = FanStartupRamp()
    let time = ContinuousClock.now
    var spinning = fan; spinning.current = 1500
    #expect(ramp.target(for: spinning, requested: 5000, at: time) == 5000)
    #expect(ramp.target(for: fan, requested: 5000, at: time) == 200)
    var second = fan; second.id = 1
    #expect(ramp.target(for: second, requested: 300, at: time) == 200)
    #expect(ramp.target(for: second, requested: 300, at: time.advanced(by: .seconds(1))) == 300)
  }
}
