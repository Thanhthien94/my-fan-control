import Foundation
import Testing

@testable import FanCore

struct ReleaseCatalogTests {
  @Test func selectsNewestVersionRatherThanGitHubListOrder() throws {
    let data = Data(#"[{"tag_name":"v0.2.9","html_url":"https://github.com/Thanhthien94/my-fan-control/releases/tag/v0.2.9","draft":false,"prerelease":false},{"tag_name":"v0.10.0-preview.1","html_url":"https://github.com/Thanhthien94/my-fan-control/releases/tag/v0.10.0-preview.1","draft":false,"prerelease":true}]"#.utf8)
    #expect(try ReleaseCatalog.newest(data, includePreviews: true)?.tag_name == "v0.10.0-preview.1")
    #expect(try ReleaseCatalog.newest(data, includePreviews: false)?.tag_name == "v0.2.9")
  }
  @Test func neverOffersDraftsOrUntrustedDownloadDestinations() throws {
    let data = Data(#"[{"tag_name":"v99.0.0","html_url":"https://evil.example/app","draft":false,"prerelease":false},{"tag_name":"v98.0.0","html_url":"https://github.com/Thanhthien94/my-fan-control/releases/tag/v98.0.0","draft":true,"prerelease":false}]"#.utf8)
    #expect(try ReleaseCatalog.newest(data, includePreviews: true) == nil)
  }
  @Test func malformedVersionsAreRejectedWithoutCrashing() {
    for version in ["", "v", "1", "0.01.0", "1.0.0-", "1.0.0-preview.01", "1.0.0+", "1.0.0-<script>"] {
      #expect(throws: (any Error).self) { try AppVersion(version) }
    }
  }
  @Test func importingSameBackupTwiceIsIdempotent() throws {
    let preset = FanPreset(name: "Work", mode: .fixed, rpm: 2000)
    let job = FanSchedule(name: "Job", fanIDs: [0], preset: preset, durationMinutes: 10,
      timing: .weekly(days: [2], hour: 9, minute: 0))
    let backup = ConfigurationBackup(presets: [preset], schedules: [job])
    let first = try backup.merge(presets: [], schedules: [])
    let second = try backup.merge(presets: first.presets, schedules: first.schedules)
    #expect(second.presets == first.presets && second.schedules == first.schedules)
  }
}
