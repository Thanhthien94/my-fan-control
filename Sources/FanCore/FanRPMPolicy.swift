import Foundation

public enum FanRPMPolicy {
  /// A stored custom zero remains intact, but protection imposes each fan's factory floor.
  public static func minimum(for fan: Fan, custom: Double?, protection: Bool) throws -> Double {
    guard fan.minimum.isFinite, fan.maximum.isFinite, fan.minimum >= 0,
      fan.maximum > fan.minimum, fan.maximum <= 20000 else {
      throw FanError.invalid(L10n.t("Giới hạn quạt không hợp lệ."))
    }
    let requested = custom ?? fan.minimum
    guard requested.isFinite, requested >= 0, requested <= fan.maximum else {
      throw FanError.invalid(L10n.f("rpm.minimumInvalid", Int(fan.maximum)))
    }
    return protection ? max(fan.minimum, requested) : requested
  }
}
