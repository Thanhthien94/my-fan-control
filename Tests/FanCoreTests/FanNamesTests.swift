import Testing

@testable import FanCore

struct FanNamesTests {
  @Test func currentMacRetainsThePreviousLeftRightLabels() {
    #expect(FanNames.name(id: 0, count: 2, model: "Mac16,7") == L10n.t("Quạt trái"))
    #expect(FanNames.name(id: 1, count: 2, model: "Mac16,7") == L10n.t("Quạt phải"))
  }
  @Test func unknownModelsOrDifferentFanCountsKeepSMCIndices() {
    #expect(FanNames.name(id: 0, count: 2, model: "Unknown") == L10n.f("fan.name", 1))
    #expect(FanNames.name(id: 1, count: 4, model: "Mac16,7") == L10n.f("fan.name", 2))
    #expect(FanNames.name(id: 0, count: 1, model: "Mac16,7") == L10n.f("fan.name", 1))
  }
}
