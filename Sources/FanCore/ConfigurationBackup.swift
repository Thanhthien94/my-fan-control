import Foundation

public struct ConfigurationBackup: Codable, Sendable {
  public var formatVersion = 1
  public var presets: [FanPreset]
  public var schedules: [FanSchedule]
  public init(presets: [FanPreset], schedules: [FanSchedule]) {
    self.presets = presets
    self.schedules = schedules
  }
  private func validate() throws {
    guard formatVersion == 1, presets.count <= 50, schedules.count <= 100,
      Set(presets.map(\.id)).count == presets.count, Set(schedules.map(\.id)).count == schedules.count
    else { throw FanError.invalid(L10n.t("backup.invalid")) }
    for preset in presets { try preset.validateDefinition() }
    for schedule in schedules { try schedule.validate() }
  }
  public func encoded() throws -> Data {
    try validate()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(self)
  }
  public static func decode(_ data: Data) throws -> Self {
    guard data.count <= 1_048_576 else { throw FanError.invalid(L10n.t("backup.tooLarge")) }
    let result = try JSONDecoder().decode(Self.self, from: data)
    try result.validate()
    return result
  }
  /// Builds a complete plan before touching preferences. Existing data is never overwritten.
  public func merge(presets existing: [FanPreset], schedules oldSchedules: [FanSchedule]) throws -> Self {
    try validate()
    var result = existing
    var mapping = [UUID: FanPreset]()
    func unique(_ base: String, among names: [String], limit: Int) -> String {
      var value = base
      var index = 2
      while names.contains(where: { $0.localizedCaseInsensitiveCompare(value) == .orderedSame }) {
        value = String(base.prefix(limit - 8)) + " (\(index))"
        index += 1
      }
      return value
    }
    for preset in presets {
      if let same = result.first(where: { candidate in
        var normalized = preset
        normalized.id = candidate.id
        return normalized == candidate
      }) {
        mapping[preset.id] = same
        continue
      }
      var copy = preset
      copy.id = UUID()
      copy.name = unique(copy.name, among: result.map(\.name), limit: 80)
      result.append(copy)
      mapping[preset.id] = copy
    }
    var scheduled = oldSchedules
    for item in schedules {
      var copy = item
      copy.preset = mapping[item.preset.id] ?? item.preset
      let duplicate = scheduled.contains { candidate in
        var normalized = copy
        normalized.id = candidate.id
        normalized.enabled = candidate.enabled
        return normalized == candidate
      }
      if duplicate { continue }
      copy.id = UUID()
      copy.enabled = false
      copy.name = unique(copy.name, among: scheduled.map(\.name), limit: 100)
      scheduled.append(copy)
    }
    guard result.count <= 50, scheduled.count <= 100 else { throw FanError.invalid(L10n.t("backup.limit")) }
    return Self(presets: result, schedules: scheduled)
  }
}
