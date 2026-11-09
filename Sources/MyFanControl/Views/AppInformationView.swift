import AppKit
import FanCore
import SwiftUI

struct AppInformationView: View {
  var store: FanStore
  var updates: UpdateStore
  @State private var document: BundledDocument?
  private let metadata = AppMetadata()
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 16) {
        Image(nsImage: AppIdentity.icon).resizable().frame(width: 76, height: 76)
        VStack(alignment: .leading, spacing: 5) {
          Text("My Fan Control").font(.title.weight(.semibold))
          Text(L10n.f("info.versionBuild", metadata.version, metadata.build)).textSelection(.enabled)
          Text(L10n.t("info.native")).font(.callout).foregroundStyle(.secondary)
        }
      }
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          Text(metadata.copyright).font(.callout)
          Text(L10n.t("info.independent")).font(.callout).foregroundStyle(.secondary)
          Label(L10n.t("info.preview"), systemImage: "info.circle").font(.callout)
            .fixedSize(horizontal: false, vertical: true)
          GroupBox(L10n.t("info.system")) {
            VStack(alignment: .leading, spacing: 8) {
              LabeledContent(L10n.t("info.hardware"), value: HardwareIdentity.chip + " · " + HardwareIdentity.model)
              LabeledContent(L10n.t("info.buildDate"), value: metadata.buildDate)
              LabeledContent("macOS", value: ProcessInfo.processInfo.operatingSystemVersionString)
              LabeledContent(L10n.t("info.requirements"), value: "Apple Silicon · macOS 14+")
              if !metadata.revision.isEmpty {
                LabeledContent(L10n.t("info.source")) {
                  Link(String(metadata.revision.prefix(12)), destination: metadata.sourceURL)
                }
              }
            }.font(.callout).padding(8).textSelection(.enabled)
          }
          HStack {
            ForEach(BundledDocument.allCases) { item in
              Button(item.title) { document = item }
            }
          }
          Text(L10n.t("info.permission")).font(.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          UpdateSection(updates: updates)
          HStack {
            Link(L10n.t("info.guide"), destination: AppMetadata.guideURL)
            Link(L10n.t("info.compatibility"), destination: AppMetadata.compatibilityURL)
            Link(L10n.t("info.reportIssue"), destination: AppMetadata.issuesURL)
          }.font(.callout)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.trailing, 4)
      }
      HStack {
        Text(L10n.t("info.localOnly")).font(.caption).foregroundStyle(.secondary)
        Spacer()
        SettingsLink { Text(L10n.t("Cài đặt…")) }
      }
    }.padding(24).frame(width: 650, height: 650)
      .sheet(item: $document) { LegalDocumentView(document: $0) }
  }
}

struct LegalDocumentView: View {
  var document: BundledDocument
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(document.title).font(.title2.weight(.semibold))
      ScrollView {
        Text(verbatim: document.contents).font(.system(size: 12, design: .monospaced))
          .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
      }
      HStack { Spacer(); Button(L10n.t("schedule.close")) { dismiss() }.keyboardShortcut(.cancelAction) }
    }.padding(24).frame(width: 660, height: 560)
  }
}

struct UpdateSection: View {
  var updates: UpdateStore
  @AppStorage("includePreviewUpdates") private var includePreviews = true
  var body: some View {
    GroupBox(L10n.t("info.updates")) {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Button {
            Task { await updates.check(includePreviews: includePreviews) }
          } label: {
            if updates.checking { ProgressView().controlSize(.small) }
            else { Text(L10n.t("update.check")) }
          }.disabled(updates.checking)
          if let release = updates.available, let url = release.safeURL {
            Link(L10n.t("update.download"), destination: url)
          }
          Spacer()
          Link(L10n.t("update.allReleases"), destination: AppMetadata.releasesURL)
        }
        Toggle(L10n.t("update.includePreviews"), isOn: $includePreviews).font(.callout).disabled(updates.checking)
          .onChange(of: includePreviews) { _, _ in updates.available = nil; updates.message = nil }
        if let message = updates.message { Text(message).font(.callout).textSelection(.enabled) }
        Text(L10n.t("update.privacy")).font(.caption).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }.padding(8)
    }
  }
}
