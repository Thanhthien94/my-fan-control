import Foundation
import FanCore
import Observation

@MainActor @Observable final class UpdateStore {
  var checking = false
  var message: String?
  var available: AppRelease?
  func check(includePreviews: Bool) async {
    guard !checking else { return }
    checking = true
    available = nil
    message = nil
    defer { checking = false }
    do {
      let current = try AppVersion(AppMetadata().version)
      let config = URLSessionConfiguration.ephemeral
      config.urlCache = nil
      config.httpCookieStorage = nil
      config.urlCredentialStorage = nil
      config.httpShouldSetCookies = false
      config.timeoutIntervalForRequest = 20
      config.timeoutIntervalForResource = 25
      let session = URLSession(configuration: config)
      defer { session.invalidateAndCancel() }
      var request = URLRequest(url: URL(string: "https://api.github.com/repos/Thanhthien94/my-fan-control/releases?per_page=20")!)
      request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
      request.setValue("MyFanControl", forHTTPHeaderField: "User-Agent")
      let (bytes, response) = try await session.bytes(for: request)
      guard let response = response as? HTTPURLResponse else { throw FanError.invalid(L10n.t("update.invalidResponse")) }
      guard response.statusCode == 200 else {
        throw FanError.invalid(L10n.t([403, 429].contains(response.statusCode) ? "update.rateLimit" : "update.failed"))
      }
      var data = Data()
      for try await byte in bytes {
        guard data.count < 1_048_576 else { throw FanError.invalid(L10n.t("update.invalidResponse")) }
        data.append(byte)
      }
      guard let release = try ReleaseCatalog.newest(data, includePreviews: includePreviews) else {
        message = L10n.t("update.noRelease")
        return
      }
      if try AppVersion(release.tag_name) > current {
        available = release
        message = L10n.f("update.available", release.tag_name)
      } else { message = L10n.f("update.current", AppMetadata().version) }
    } catch { message = L10n.t("update.failed") + " " + error.localizedDescription }
  }
}
