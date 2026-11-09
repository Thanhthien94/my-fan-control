import Foundation
import Testing

@testable import FanCore

struct SensorPickerTests {
  @Test func knownComponentsComeBeforeUnknownKeys() {
    let sensors = [
      Sensor(id: "TAOL", name: "Unknown", celsius: 40),
      Sensor(id: "TB1T", name: "Battery", celsius: 35),
      Sensor(id: "Tg1U", name: "GPU", celsius: 50),
      Sensor(id: "Tp01", name: "CPU", celsius: 55),
    ]
    let groups = SensorPickerGroup.make(sensors, includeUnknown: true, chip: "Apple M4 Pro")
    #expect(groups.map(\.component) == [.cpu, .gpu, .battery, .unknown])
    #expect(groups.flatMap(\.sensors).map(\.id) == ["Tp01", "Tg1U", "TB1T", "TAOL"])
    #expect(groups.last?.sensors.first?.id == "TAOL")
  }
  @Test func defaultListHidesUnknownChannelsButKeepsTheSelectedOne() {
    let sensors = [Sensor(id: "TCMz", name: "Unknown", celsius: 50),
      Sensor(id: "TAOL", name: "Unknown", celsius: 40),
      Sensor(id: "Tp01", name: "CPU", celsius: 55)]
    #expect(SensorPickerGroup.make(sensors, chip: "Apple M4 Pro").flatMap(\.sensors).map(\.id) == ["Tp01"])
    #expect(SensorPickerGroup.make(sensors, selectedID: "TCMz", chip: "Apple M4 Pro").flatMap(\.sensors).map(\.id) == ["Tp01", "TCMz"])
  }
  @Test func orderingDoesNotJumpWhenTemperaturesChange() {
    let sensors = [Sensor(id: "Tp05", name: "CPU 2", celsius: 55), Sensor(id: "Tp01", name: "CPU 1", celsius: 75)]
    let cold = sensors.map { Sensor(id: $0.id, name: $0.name, celsius: 30) }
    #expect(SensorPickerGroup.make(sensors, chip: "Apple M4 Pro").flatMap(\.sensors).map(\.id)
      == SensorPickerGroup.make(cold, chip: "Apple M4 Pro").flatMap(\.sensors).map(\.id))
  }
  @Test func unknownLabelDoesNotRepeatItsKey() {
    let sensor = Sensor(id: "TCMz", name: "Unknown · TCMz", celsius: 50)
    let label = SensorPickerGroup.label(sensor, chip: "Apple M4 Pro")
    #expect(label.components(separatedBy: "TCMz").count == 2)
  }
}
