import Foundation
import FanCore

struct SchedulePresetChoice: Identifiable {
  var id: String
  var preset: FanPreset
  var isSnapshot: Bool
  static func make(library: [FanPreset], saved: FanPreset?) -> [Self] {
    var result = library.filter { $0.mode != .automatic }.map {
      Self(id: $0.id.uuidString, preset: $0, isSnapshot: false)
    }
    if let saved, !result.contains(where: { $0.preset == saved }) {
      result.insert(Self(id: "snapshot-" + saved.id.uuidString, preset: saved, isSnapshot: true), at: 0)
    }
    return result
  }
}
