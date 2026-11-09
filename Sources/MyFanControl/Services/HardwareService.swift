import FanCore
import Foundation

protocol HardwareBackend: Sendable {
  func read() async throws -> Snapshot
  func send(_ request: HelperRequest) async throws -> HelperResponse
  func authorize() async throws
  func authorizationFailure() async -> String?
  func cancelAuthorization() async
}
extension HardwareBackend {
  func authorizationFailure() async -> String? { nil }
  func cancelAuthorization() async {}
}

actor HardwareService: HardwareBackend {
  private var smc: SMC?
  private var authorizationProcess: Process?
  private var authorizationID = UUID()
  private var startupFailure: String?
  func read() throws -> Snapshot {
    if smc == nil { smc = try SMC() }
    do { return try smc!.snapshot() } catch {
      smc = nil
      throw error
    }  // Reconnect after wake or an invalidated IOKit connection.
  }
  func send(_ request: HelperRequest) throws -> HelperResponse { try HelperClient.request(request) }

  func authorize() throws {
    if authorizationProcess?.isRunning == true { return }
    guard let helper = Bundle.main.url(forAuxiliaryExecutable: "fanctl"),
      FileManager.default.isExecutableFile(atPath: helper.path)
    else {
      throw FanError.helper(
        L10n.t("Không tìm thấy helper trong app bundle. Hãy chạy bằng script/build_and_run.sh."))
    }
    func quote(_ s: String) -> String {
      "'" + s.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
    // Keep the authorized service in the foreground of its launcher. Return immediately
    // and let the GUI handshake concurrently; no detached shell jobs or swallowed errors.
    var repair = ""
    if let status = try? HelperClient.request(HelperRequest("status")), status.protocolVersion != 3,
      let pid = HelperClient.serverPID()
    {
      repair = "\(quote(helper.path)) retire --uid \(getuid()) --pid \(pid); "
    }
    let shell = "set -e; \(repair)exec \(quote(helper.path)) serve --uid \(getuid())"
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
    process.standardInput = FileHandle.nullDevice
    let id = UUID()
    authorizationID = id
    startupFailure = nil
    process.terminationHandler = { [weak self] finished in
      let message = String(
        decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
      Task {
        await self?.authorizationDidExit(
          id: id, status: finished.terminationStatus, message: message)
      }
    }
    try process.run()
    authorizationProcess = process
  }
  private func authorizationDidExit(id: UUID, status: Int32, message: String) {
    guard id == authorizationID else { return }
    authorizationProcess = nil
    if status != 0 {
      startupFailure =
        message.contains("-128")
        ? L10n.t("Đã hủy cấp quyền.")
        : L10n.f(
          "preset.startFailure",
          String(message.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1200)))
    }
  }
  func authorizationFailure() -> String? { startupFailure }
  func cancelAuthorization() {
    if authorizationProcess?.isRunning == true { authorizationProcess?.terminate() }
  }
}
