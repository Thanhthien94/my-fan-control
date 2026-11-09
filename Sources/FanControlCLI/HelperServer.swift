import CSMC
import Darwin
import FanCore
import Foundation

final class HelperServer {
  private let session: ControlSession
  private let uid: uid_t
  private var lastContact = ContinuousClock.now
  private var running = true
  init(uid: uid_t) throws {
    self.uid = uid
    self.session = ControlSession(hardware: try SMC())
  }
  func run() throws {
    guard geteuid() == 0, uid > 0 else {
      throw FanError.helper(L10n.t("Helper cần quyền quản trị và UID người dùng hợp lệ."))
    }
    let path = HelperClient.path(uid: uid)
    let server = mfc_listen(path, uid)
    guard server >= 0 else {
      throw FanError.helper(L10n.t("Không mở được socket helper; một phiên khác có thể đang chạy."))
    }
    mfc_install_signal_handlers()
    defer {
      session.restoreAll()
      close(server)
      unlink(path)
    }
    while running {
      if mfc_stop_requested() != 0 {
        if session.restoreAll() { break }
        // Stop accepting new policies while restoration is being retried.
        sleep(1)
        continue
      }
      let age = Double(lastContact.duration(to: .now).components.seconds)
      if age >= 10 {
        // Keep retrying restore instead of abandoning a manually controlled fan.
        if session.restoreAll() { break }
      }
      session.tick(leaseAge: age)
      guard mfc_wait(server, 1) > 0 else { continue }
      let client = mfc_accept(server, uid)
      guard client >= 0 else { continue }
      var buffer = [CChar](repeating: 0, count: 4096)
      let n = mfc_receive(client, &buffer, buffer.count)
      var response: HelperResponse
      do {
        guard n > 0 else { throw FanError.invalid(L10n.t("Lệnh trống hoặc vượt giới hạn.")) }
        let data = Data(buffer.prefix(Int(n)).map { UInt8(bitPattern: $0) })
        let request = try JSONDecoder().decode(HelperRequest.self, from: data)
        if let language = request.language, ["vi", "en"].contains(language) {
          L10n.languageOverride = language
        }
        response = try handle(request)
        lastContact = .now
      } catch {
        response = HelperResponse(
          ok: false, message: error.localizedDescription, controlled: session.activeIDs.sorted(),
          restoring: session.restoringIDs.sorted())
      }
      if var data = try? JSONEncoder().encode(response) {
        data.append(10)
        let sent = data.withUnsafeBytes {
          mfc_send(client, $0.baseAddress!.assumingMemoryBound(to: CChar.self), data.count)
        }
        if sent != 0 { session.restoreAll() }
      }
      close(client)
    }
  }
  private func handle(_ request: HelperRequest) throws -> HelperResponse {
    switch request.command {
    case "status": break
    case "configure":
      guard let id = request.fanID, let rule = request.preset else {
        throw FanError.invalid(L10n.t("Thiếu quạt hoặc preset."))
      }
      try session.configure(id: id, rule: rule)
    case "configureGroup":
      guard let ids = request.fanIDs, let rule = request.preset else {
        throw FanError.invalid(L10n.t("group.invalid"))
      }
      try session.configureGroup(ids: ids, rule: rule)
    case "automatic":
      guard session.restoreAll() else {
        throw FanError.helper(session.notice ?? L10n.t("Không khôi phục được quạt."))
      }
      session.acknowledgeNotice()
    case "shutdown":
      guard session.restoreAll() else {
        throw FanError.helper(session.notice ?? L10n.t("Không khôi phục được quạt."))
      }
      running = false
      session.acknowledgeNotice()
    default: throw FanError.invalid(L10n.t("Lệnh không được hỗ trợ."))
    }
    return HelperResponse(
      ok: true, message: session.notice, controlled: session.activeIDs.sorted(),
      restoring: session.restoringIDs.sorted())
  }
}
