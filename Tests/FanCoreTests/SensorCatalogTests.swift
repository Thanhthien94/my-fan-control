import Testing

@testable import FanCore

struct SensorCatalogTests {
  @Test func sameKeyChangesMeaningAcrossChipGenerations() {
    #expect(SensorCatalog.lookup("Tp0P", chip: "Intel Core i7").component == .mainboard)
    #expect(SensorCatalog.lookup("Tp0P", chip: "Apple M1 Pro").component == .cpu)
    #expect(!SensorCatalog.lookup("Tp0P", chip: "Apple M4 Pro").known)
    #expect(
      SensorCatalog.lookup("Tp09", chip: "Apple M1").name
        != SensorCatalog.lookup("Tp09", chip: "Apple M4").name)
  }
  @Test func m4ProMappingsAreScopedAndCaseSensitive() {
    #expect(SensorCatalog.lookup("Tg1U", chip: "Apple M4 Pro").component == .gpu)
    #expect(!SensorCatalog.lookup("Tg1U", chip: "Apple M4").known)
    #expect(SensorCatalog.lookup("Tm0p", chip: "Apple M4 Pro").component == .memory)
    #expect(SensorCatalog.lookup("Tm0P", chip: "Apple M4 Pro").component == .mainboard)
    #expect(SensorCatalog.lookup("TH0x", chip: "Apple M4 Pro").component == .storage)
  }
  @Test func unknownTelemetryNeverGetsAGuessedComponent() {
    for key in ["TCMz", "TVXh", "Ts0P", "Tp23", "TB0T"] {
      #expect(!SensorCatalog.lookup(key, chip: "Apple M4 Pro").known)
    }
    #expect(SensorCatalog.lookup("TB1T", chip: "Apple M4 Pro").component == .battery)
    #expect(SensorCatalog.lookup("TW0P", chip: "Apple M4 Pro").component == .wireless)
  }
}
