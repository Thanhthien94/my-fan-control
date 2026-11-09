import Foundation
import Testing

@testable import FanCore

struct LocalizationTests {
  @Test func englishAndVietnameseResolveWithoutChangingKeys() {
    #expect(L10n.text("Tự động", language: "en") == "Automatic")
    #expect(L10n.text("Tự động", language: "vi") == "Tự động")
    #expect(L10n.text("sensor.name", language: "en") == "Sensor %@")
    #expect(L10n.text("sensor.name", language: "vi") == "Cảm biến %@")
    #expect(L10n.text("language", language: "en") == "Language")
  }
}
