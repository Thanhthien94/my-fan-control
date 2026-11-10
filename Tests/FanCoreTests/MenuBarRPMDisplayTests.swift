import Foundation
import Testing

@testable import FanCore

struct MenuBarRPMDisplayTests {
  private let fans = [
    Fan(id: 1, name: "Right", current: 1458, minimum: 1350, maximum: 5777),
    Fan(id: 0, name: "Left", current: 1350, minimum: 1350, maximum: 5777),
  ]
  @Test func previousCheckboxChoiceIsPreserved() {
    #expect(MenuBarRPMDisplay.resolve(stored: "", legacyShowRPM: true) == .highest)
    #expect(MenuBarRPMDisplay.resolve(stored: "", legacyShowRPM: false) == .hidden)
    #expect(MenuBarRPMDisplay.resolve(stored: "all", legacyShowRPM: true) == .all)
  }
  @Test func highestAndHiddenBehaveAsBefore() {
    #expect(MenuBarRPMDisplay.highest.readout(fans, model: "Mac16,7") == "1458 RPM")
    #expect(MenuBarRPMDisplay.hidden.readout(fans, model: "Mac16,7") == nil)
  }
  @Test func allFansAreLabeledAndFollowSMCOrder() {
    let expected = L10n.t("fan.short.left") + " 1350 | " + L10n.t("fan.short.right") + " 1458 RPM"
    #expect(MenuBarRPMDisplay.all.readout(fans, model: "Mac16,7") == expected)
  }
  @Test func unknownTopologyKeepsNumberedLabels() {
    let expected = L10n.f("fan.short.number", 1) + " 1350 | " + L10n.f("fan.short.number", 2) + " 1458 RPM"
    #expect(MenuBarRPMDisplay.all.readout(fans, model: "Unknown") == expected)
  }
  @Test func unavailableAndStoppedFansAreDistinct() {
    #expect(MenuBarRPMDisplay.highest.readout([], model: "Unknown") == "— RPM")
    let stopped = Fan(id: 0, name: "Fan", current: 0, minimum: 0, maximum: 6000)
    #expect(MenuBarRPMDisplay.highest.readout([stopped], model: "Unknown") == "0 RPM")
    var invalid = stopped
    invalid.current = .nan
    #expect(MenuBarRPMDisplay.highest.readout([invalid], model: "Unknown") == "— RPM")
  }
}
