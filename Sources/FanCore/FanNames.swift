import Foundation

public enum FanNames {
  /// Preserve the existing display convention on the tested Mac. These aliases
  /// never change SMC IDs; unrecognized models/topologies retain numbered names.
  public static func name(id: Int, count: Int, model: String) -> String {
    if model == "Mac16,7", count == 2, (0..<2).contains(id) {
      return L10n.t(id == 0 ? "Quạt trái" : "Quạt phải")
    }
    return L10n.f("fan.name", id + 1)
  }
}
