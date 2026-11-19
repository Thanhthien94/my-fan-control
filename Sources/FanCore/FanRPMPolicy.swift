import Foundation

public enum FanRPMPolicy {
  /// Manual policies use the hardware floor; legacy raw preset values are clamped to it.
  public static func minimum(for fan: Fan) throws -> Double {
    guard fan.minimum.isFinite, fan.maximum.isFinite, fan.minimum >= 0,
      fan.maximum > fan.minimum, fan.maximum <= 20000 else {
      throw FanError.invalid(L10n.t("Giới hạn quạt không hợp lệ."))
    }
    return fan.minimum
  }
}
