import AppKit
import FanCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  var store: FanStore?
  func applicationDidFinishLaunching(_ notification: Notification) {
    let args = CommandLine.arguments
    if let i = args.firstIndex(of: "--ui-appearance"), args.indices.contains(i + 1) {
      if args[i + 1] == "dark" { NSApp.appearance = NSAppearance(named: .darkAqua) }
      if args[i + 1] == "light" { NSApp.appearance = NSAppearance(named: .aqua) }
    }
    NSApp.setActivationPolicy(.regular)
    NSApp.applicationIconImage = AppIdentity.icon
    NSApp.activate(ignoringOtherApps: true)
  }
  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard let store else { return .terminateNow }
    Task { @MainActor in
      await store.shutdown()
      sender.reply(toApplicationShouldTerminate: true)
    }
    return .terminateLater
  }
}

@main struct MyFanControlApp: App {
  init() {
    let args = CommandLine.arguments
    if let i = args.firstIndex(of: "--ui-language"), args.indices.contains(i + 1),
      ["vi", "en"].contains(args[i + 1])
    {
      L10n.languageOverride = args[i + 1]
    }
  }
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
  @State private var store = FanStore()
  @AppStorage("language") private var language = "system"
  var body: some Scene {
    WindowGroup("My Fan Control", id: "main") {
      ContentView(store: store)
        .id(language)
        .environment(\.locale, Locale(identifier: L10n.language))
        .frame(minWidth: 1000, minHeight: 760)
        .task {
          delegate.store = store
          store.start()
        }
    }
    .defaultSize(width: 1080, height: 820)
    .commands {
      CommandGroup(replacing: .appInfo) {
        Button(L10n.t("legal.about")) {
          NSApp.orderFrontStandardAboutPanel(options: [
            .applicationIcon: AppIdentity.icon,
            .credits: NSAttributedString(string: L10n.t("legal.credits")),
          ])
        }
      }
      CommandGroup(after: .newItem) {
        Button(L10n.t("Tất cả về tự động")) { Task { await store.restoreAll() } }
          .keyboardShortcut("a", modifiers: [.command, .shift]).disabled(!store.helperEnabled)
        Button(L10n.t("Cập nhật cảm biến")) { Task { await store.refresh() } }
          .keyboardShortcut("r", modifiers: .command)
      }
    }
    MenuBarExtra {
      FanMenu(store: store)
        .id(language)
    } label: {
      MenuBarLabel(store: store)
    }
    Settings { SettingsView().id(language).frame(width: 460, height: 280) }
  }
}

struct MenuBarLabel: View {
  var store: FanStore
  var body: some View {
    Label(store.hottest.map { String(format: "%.0f°C", $0.celsius) } ?? "—°C", systemImage: "fan")
  }
}

struct FanMenu: View {
  var store: FanStore
  @Environment(\.openWindow) private var openWindow
  var body: some View {
    Text("My Fan Control")
    if let sensor = store.hottest {
      Text(String(format: L10n.t("Nóng nhất: %.1f°C"), sensor.celsius))
    }
    ForEach(store.fans) { fan in Text("\(fan.name): \(Int(fan.current)) RPM") }
    Divider()
    Button(L10n.t("Mở bảng điều khiển")) {
      openWindow(id: "main")
      NSApp.activate(ignoringOtherApps: true)
    }
    Button(L10n.t("Tất cả về tự động")) { Task { await store.restoreAll() } }.disabled(
      !store.helperEnabled)
    Divider()
    SettingsLink { Text(L10n.t("Cài đặt…")) }
    Button(L10n.t("Thoát My Fan Control")) { NSApp.terminate(nil) }.keyboardShortcut("q")
  }
}

struct SettingsView: View {
  @AppStorage("language") private var language = "system"
  @AppStorage("fahrenheit") private var fahrenheit = false
  var body: some View {
    Form {
      Picker(L10n.t("language"), selection: $language) {
        Text(L10n.t("language.system")).tag("system")
        Text("Tiếng Việt").tag("vi")
        Text("English").tag("en")
      }.pickerStyle(.segmented)
      Text(L10n.t("language.note")).font(.caption).foregroundStyle(.secondary)
      Toggle(L10n.t("Hiển thị cảm biến bằng °F"), isOn: $fahrenheit)
      LabeledContent(L10n.t("Cập nhật"), value: L10n.t("Mỗi 2 giây"))
      Text(
        L10n.t("Đóng cửa sổ vẫn giữ app trong menu bar. Thoát app sẽ yêu cầu trả quạt về tự động.")
      )
      .font(.callout).foregroundStyle(.secondary)
    }.padding(24)
  }
}
