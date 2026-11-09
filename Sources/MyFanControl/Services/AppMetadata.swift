import Foundation
import FanCore

struct AppMetadata: Sendable {
  let version: String
  let build: String
  let revision: String
  let buildDate: String
  let copyright: String
  init(info: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
    version = info["MFCReleaseLabel"] as? String ?? info["CFBundleShortVersionString"] as? String ?? "Development"
    build = info["CFBundleVersion"] as? String ?? "—"
    let candidate = info["MFCSourceRevision"] as? String ?? ""
    revision = candidate.count == 40 && candidate.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) ? candidate : ""
    buildDate = info["MFCBuildDate"] as? String ?? "—"
    copyright = info["NSHumanReadableCopyright"] as? String ?? "Copyright © 2026 Thanhthien94. MIT License."
  }
  var sourceURL: URL { URL(string: "https://github.com/Thanhthien94/my-fan-control/tree/" + (revision.isEmpty ? "main" : revision))! }
  static let releasesURL = URL(string: "https://github.com/Thanhthien94/my-fan-control/releases")!
  static let issuesURL = URL(string: "https://github.com/Thanhthien94/my-fan-control/issues/new/choose")!
  static let guideURL = URL(string: "https://github.com/Thanhthien94/my-fan-control/blob/main/INSTALL.md")!
  static let compatibilityURL = URL(string: "https://github.com/Thanhthien94/my-fan-control/blob/main/docs/apple-silicon-compatibility.md")!
}
