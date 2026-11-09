import Foundation

public struct SensorPickerGroup: Identifiable, Sendable {
  public var id: String { component.rawValue }
  public let component: SensorComponent
  public let sensors: [Sensor]

  /// Component order is deliberate; temperature changes never reorder this menu.
  /// Keep an explicitly selected unknown channel visible without resetting its ID.
  public static func make(
    _ sensors: [Sensor], selectedID: String = "", includeUnknown: Bool = false,
    chip: String = HardwareIdentity.chip
  ) -> [Self] {
    let entries = sensors.map { (sensor: $0, info: SensorCatalog.lookup($0.id, chip: chip)) }
      .filter { $0.info.known || includeUnknown || $0.sensor.id == selectedID }
    return SensorComponent.allCases.compactMap { component in
      let values = entries.filter { $0.info.component == component }.sorted { a, b in
        let order = a.info.name.localizedStandardCompare(b.info.name)
        return order == .orderedSame ? a.sensor.id < b.sensor.id : order == .orderedAscending
      }.map(\.sensor)
      return values.isEmpty ? nil : Self(component: component, sensors: values)
    }
  }
  public static func label(_ sensor: Sensor, chip: String = HardwareIdentity.chip) -> String {
    let info = SensorCatalog.lookup(sensor.id, chip: chip)
    return info.known ? info.name + " · " + sensor.id : info.name
  }
}
