import FanCore
import Foundation

protocol HardwareBackend: Sendable {
  func read() async throws -> Snapshot
  func send(_ request: HelperRequest) async throws -> HelperResponse
  func authorize() async throws
}

actor HardwareService: HardwareBackend {
  private var smc: SMC?
  func read() throws -> Snapshot {
    if smc == nil { smc = try SMC() }
    return try smc!.snapshot()
  }
  func send(_ request: HelperRequest) throws -> HelperResponse { try HelperClient.request(request) }

  func authorize() throws {
    guard let helper = Bundle.main.url(forAuxiliaryExecutable: "fanctl"),
      FileManager.default.isExecutableFile(atPath: helper.path)
    else {
      throw FanError.helper(
        L10n.t("Không tìm thấy helper trong app bundle. Hãy chạy bằng script/build_and_run.sh."))
    }
    func quote(_ s: String) -> String {
      "'" + s.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
    let shell = "/usr/bin/nohup \(quote(helper.path)) serve --uid \(getuid()) >/dev/null 2>&1 &"
    let literal =
      "\""
      + shell.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(
        of: "\"", with: "\\\"") + "\""
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", "do shell script \(literal) with administrator privileges"]
    let errors = Pipe()
    process.standardError = errors
    process.standardOutput = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      let message = String(
        decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
      throw FanError.helper(
        message.contains("-128")
          ? L10n.t("Đã hủy cấp quyền.")
          : L10n.f("error.authorization", message.trimmingCharacters(in: .whitespacesAndNewlines)))
    }
  }
}
