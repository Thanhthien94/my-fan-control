import CSMC
import Darwin
import Foundation

public struct HelperRequest: Codable {
  public var command: String
  public var language: String?
  public var fanID: Int?
  public var fanIDs: [Int]?
  public var preset: FanPreset?
  public init(_ command: String, fanID: Int? = nil, fanIDs: [Int]? = nil, preset: FanPreset? = nil)
  {
    self.command = command
    self.fanID = fanID
    self.fanIDs = fanIDs
    self.preset = preset
    self.language = L10n.language
  }
}
public struct HelperResponse: Codable {
  public static let currentProtocolVersion = 7
  public var ok: Bool
  public var message: String?
  public var controlled: [Int]
  public var protocolVersion: Int?
  public var restoring: [Int]?
  public init(ok: Bool, message: String? = nil, controlled: [Int] = [], restoring: [Int] = []) {
    self.ok = ok
    self.message = message
    self.controlled = controlled
    self.protocolVersion = Self.currentProtocolVersion
    self.restoring = restoring
  }
}
public enum HelperClient {
  public static func serverPID(uid: uid_t = getuid()) -> Int32? {
    let fd = mfc_connect(path(uid: uid))
    guard fd >= 0 else { return nil }
    defer { close(fd) }
    let pid = mfc_peer_pid(fd)
    return pid > 1 ? pid : nil
  }
  public static func path(uid: uid_t = getuid()) -> String {
    "/var/run/vn.thiendev.myfancontrol-\(uid).sock"
  }
  public static func request(_ request: HelperRequest) throws -> HelperResponse {
    let fd = mfc_connect(path())
    guard fd >= 0 else { throw FanError.helper(L10n.t("Chưa bật quyền điều khiển quạt.")) }
    defer { close(fd) }
    var data = try JSONEncoder().encode(request)
    data.append(10)
    let sent = data.withUnsafeBytes {
      mfc_send(fd, $0.baseAddress!.assumingMemoryBound(to: CChar.self), data.count)
    }
    guard sent == 0 else { throw FanError.helper(L10n.t("Không gửi được lệnh đến helper.")) }
    var buffer = [CChar](repeating: 0, count: 8192)
    let n = mfc_receive_reply(fd, &buffer, buffer.count)
    guard n > 0 else { throw FanError.helper(L10n.t("Helper không phản hồi.")) }
    let response = try JSONDecoder().decode(
      HelperResponse.self, from: Data(buffer.prefix(Int(n)).map { UInt8(bitPattern: $0) }))
    guard response.ok else {
      throw FanError.helper(response.message ?? L10n.t("Helper từ chối lệnh."))
    }
    return response
  }
}

/// A continuous-clock lease and fresh temperatures are both required for manual control.
public enum ControlSafety {
  public static func permits(leaseAge: Double, sensors: [Sensor]) -> Bool {
    leaseAge.isFinite && leaseAge >= 0 && leaseAge < 10 && !sensors.isEmpty
      && sensors.allSatisfy { $0.celsius.isFinite && $0.celsius > 0 && $0.celsius < 90 }
  }
}
