import Foundation

/// Capabilities observed from read-only SMC queries, not a certification of writable control.
public struct CompatibilityReport: Codable, Sendable {
  public struct FanCapability: Codable, Sendable {
    public var fan: Fan
    public var modeKey: String?
    public var legacyMaskAvailable: Bool
    public var targetAvailable: Bool
  }
  public var chip: String
  public var model: String
  public var fanAvailability: FanAvailability
  public var gateAvailable: Bool
  public var fans: [FanCapability]
  public var readableTemperatureCount: Int
  public var mappedTemperatureCount: Int
}
