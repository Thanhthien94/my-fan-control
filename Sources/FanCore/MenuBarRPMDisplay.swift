import Foundation

public enum MenuBarRPMDisplay: String, CaseIterable, Sendable {
  case hidden, highest, all
  public var title: String { L10n.t("settings.menuRPM." + rawValue) }
  public static func resolve(stored: String, legacyShowRPM: Bool) -> Self {
    Self(rawValue: stored) ?? (legacyShowRPM ? .highest : .hidden)
  }
  public func readout(_ fans: [Fan], model: String = HardwareIdentity.model) -> String? {
    func value(_ fan: Fan) -> String? {
      guard fan.current.isFinite, (0...20000).contains(fan.current) else { return nil }
      return String(Int(fan.current))
    }
    switch self {
    case .hidden: return nil
    case .highest:
      let maximum = fans.compactMap { fan in value(fan).map { _ in fan.current } }.max()
      return maximum.map { "\(Int($0)) RPM" } ?? "— RPM"
    case .all:
      guard !fans.isEmpty else { return "— RPM" }
      let parts = fans.sorted { $0.id < $1.id }.map { fan in
        FanNames.compactName(id: fan.id, count: fans.count, model: model) + " " + (value(fan) ?? "—")
      }
      return parts.joined(separator: " | ") + " RPM"
    }
  }
}
