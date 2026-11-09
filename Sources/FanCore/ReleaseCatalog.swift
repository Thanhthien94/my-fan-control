import Foundation

public struct AppRelease: Decodable, Sendable {
  public let tag_name: String
  public let html_url: URL
  public let draft: Bool
  public let prerelease: Bool
  public var safeURL: URL? {
    guard let url = URLComponents(url: html_url, resolvingAgainstBaseURL: false),
      url.scheme == "https", url.host == "github.com", url.port == nil || url.port == 443,
      url.user == nil, url.password == nil,
      url.path.hasPrefix("/Thanhthien94/my-fan-control/releases/tag/"), url.query == nil
    else { return nil }
    return html_url
  }
}
public enum ReleaseCatalog {
  public static func newest(_ data: Data, includePreviews: Bool) throws -> AppRelease? {
    guard data.count <= 1_048_576 else { throw FanError.invalid(L10n.t("update.invalidResponse")) }
    let releases = try JSONDecoder().decode([AppRelease].self, from: data)
    return releases.filter { !$0.draft && (includePreviews || !$0.prerelease) && $0.safeURL != nil && (try? AppVersion($0.tag_name)) != nil }.max {
      // Invalid versions were filtered above.
      (try! AppVersion($0.tag_name)) < (try! AppVersion($1.tag_name))
    }
  }
}
