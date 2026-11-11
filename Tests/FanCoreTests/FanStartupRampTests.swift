import Testing
@testable import FanCore

struct FanStartupRampTests {
  let fan = Fan(id: 0, name: "Fan", current: 0, minimum: 1200, maximum: 6000)
  @Test func startsAtHardwareFloorAndUsesMonotonic500RPMSteps() {
    var ramp = FanStartupRamp()
    var time = ContinuousClock.now
    #expect(ramp.target(for: fan, requested: 5000, at: time, minimumRPM: 1200) == 1200)
    #expect(ramp.target(for: fan, requested: 5000, at: time, minimumRPM: 1200) == 1200)
    for expected in [1700.0, 2200, 2700, 3200, 3700] {
      time = time.advanced(by: .seconds(1))
      #expect(ramp.target(for: fan, requested: 5000, at: time, minimumRPM: 1200) == expected)
    }
  }
  @Test func reductionIsImmediateAndLongPauseCannotCauseCatchUpJump() {
    var ramp = FanStartupRamp()
    let time = ContinuousClock.now
    #expect(ramp.target(for: fan, requested: 5000, at: time, minimumRPM: 1200) == 1200)
    #expect(ramp.target(for: fan, requested: 5000, at: time.advanced(by: .seconds(30)), minimumRPM: 1200) == 2200)
    #expect(ramp.target(for: fan, requested: 1500, at: time.advanced(by: .seconds(31)), minimumRPM: 1200) == 1500)
    #expect(ramp.target(for: fan, requested: 0, at: time.advanced(by: .seconds(32)), minimumRPM: 1200) == 1200)
  }
  @Test func spinningFansIncreaseFromCurrentRPMAndEachFanHasIndependentState() {
    var ramp = FanStartupRamp()
    let time = ContinuousClock.now
    var spinning = fan; spinning.current = 2500
    #expect(ramp.target(for: spinning, requested: 5000, at: time, minimumRPM: 1200) == 2500)
    var second = fan; second.id = 1
    #expect(ramp.target(for: second, requested: 1800, at: time, minimumRPM: 1500) == 1500)
    #expect(ramp.target(for: second, requested: 1800, at: time.advanced(by: .seconds(1)), minimumRPM: 1500) == 1800)
    #expect(ramp.target(for: spinning, requested: 5000, at: time.advanced(by: .seconds(1)), minimumRPM: 1200) == 3000)
  }
}
