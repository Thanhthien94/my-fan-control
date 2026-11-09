import AppKit
import UniformTypeIdentifiers
import FanCore

@MainActor enum ReleaseFiles {
  static func save(_ data: Data, name: String, type: UTType) async throws -> Bool {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [type]
    panel.nameFieldStringValue = name
    panel.canCreateDirectories = true
    let response = await withCheckedContinuation { continuation in
      panel.begin { continuation.resume(returning: $0) }
    }
    guard response == .OK, let url = panel.url else { return false }
    try data.write(to: url, options: .atomic)
    return true
  }
  static func openBackup() async throws -> Data? {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    let response = await withCheckedContinuation { continuation in
      panel.begin { continuation.resume(returning: $0) }
    }
    guard response == .OK, let url = panel.url else { return nil }
    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    guard size <= 1_048_576 else { throw FanError.invalid(L10n.t("backup.tooLarge")) }
    return try Data(contentsOf: url)
  }
}

enum BundledDocument: String, CaseIterable, Identifiable {
  case license, thirdParty, privacy
  var id: String { rawValue }
  var title: String { L10n.t("info." + rawValue) }
  var contents: String {
    let name: String
    let ext: String
    switch self {
    case .license: name = "LICENSE"; ext = "txt"
    case .thirdParty: name = "THIRD_PARTY_NOTICES"; ext = "md"
    case .privacy: name = "PRIVACY"; ext = "md"
    }
    guard let url = Bundle.main.url(forResource: name, withExtension: ext),
      let text = try? String(contentsOf: url, encoding: .utf8) else { return L10n.t("info.missingDocument") }
    return text
  }
}
