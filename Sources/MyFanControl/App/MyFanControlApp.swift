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
      guard !store.helperEnabled else {
        sender.reply(toApplicationShouldTerminate: false)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.t("quit.restoreFailed")
        alert.informativeText = store.error ?? L10n.t("schedule.restorePending")
        alert.addButton(withTitle: L10n.t("quit.stayOpen"))
        if let window = sender.keyWindow { alert.beginSheetModal(for: window, completionHandler: { _ in }) }
        else { alert.runModal() }
        return
      }
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
  @State private var updates = UpdateStore()
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
    .commands { AppCommands(store: store, updates: updates) }
    Window(L10n.t("legal.about"), id: "about") {
      AppInformationView(store: store, updates: updates).id(language)
        .environment(\.locale, Locale(identifier: L10n.language))
    }.windowResizability(.contentSize).defaultPosition(.center)
    MenuBarExtra {
      FanMenu(store: store)
        .id(language)
    } label: {
      MenuBarLabel(store: store)
    }
    Settings { SettingsView(store: store, updates: updates).id(language)
      .environment(\.locale, Locale(identifier: L10n.language)) }
  }
}

struct AppCommands: Commands {
  var store: FanStore
  var updates: UpdateStore
  @Environment(\.openWindow) private var openWindow
  var body: some Commands {
    CommandGroup(replacing: .appInfo) {
      Button(L10n.t("legal.about")) { openWindow(id: "about"); NSApp.activate(ignoringOtherApps: true) }
      Button(L10n.t("update.check")) {
        openWindow(id: "about")
        Task { await updates.check(includePreviews: UserDefaults.standard.object(forKey: "includePreviewUpdates") as? Bool ?? true) }
      }.disabled(updates.checking)
    }
    CommandGroup(after: .newItem) {
      Button(L10n.t("Tất cả về tự động")) { Task { await store.restoreAll() } }
        .keyboardShortcut("a", modifiers: [.command, .shift]).disabled(!store.helperEnabled || store.busy)
      Button(L10n.t("Cập nhật cảm biến")) { Task { await store.refresh() } }
        .keyboardShortcut("r", modifiers: .command).disabled(store.busy)
    }
    CommandGroup(replacing: .help) {
      Link(L10n.t("info.guide"), destination: AppMetadata.guideURL)
      Link(L10n.t("info.compatibility"), destination: AppMetadata.compatibilityURL)
      Link(L10n.t("info.reportIssue"), destination: AppMetadata.issuesURL)
      Button(L10n.t("legal.about")) { openWindow(id: "about") }
    }
  }
}

struct MenuBarLabel: View {
  var store: FanStore
  @AppStorage("fahrenheit") private var fahrenheit = false
  @AppStorage("menuBarSensorID") private var sensorID = ""
  @AppStorage("menuBarShowRPM") private var showRPM = false
  private var sensor: Sensor? { sensorID.isEmpty ? store.hottest : store.sensors.first { $0.id == sensorID } }
  private var label: String {
    let unit: TemperatureUnit = fahrenheit ? .fahrenheit : .celsius
    let text = sensor.map { unit.text($0.celsius, decimals: 0) } ?? "—" + unit.symbol
    guard showRPM, let rpm = store.fans.map(\.current).max() else { return text }
    return text + " · \(Int(rpm)) RPM"
  }
  var body: some View { Label(label, systemImage: "fan") }
}

struct FanMenu: View {
  var store: FanStore
  @Environment(\.openWindow) private var openWindow
  @AppStorage("fahrenheit") private var fahrenheit = false
  var body: some View {
    Text("My Fan Control")
    if let sensor = store.hottest {
      Text(L10n.t("Cảm biến nóng nhất") + ": " + (fahrenheit ? TemperatureUnit.fahrenheit : .celsius).text(sensor.celsius))
    }
    ForEach(store.fans) { fan in Text("\(fan.name): \(Int(fan.current)) RPM") }
    Divider()
    Button(L10n.t("Mở bảng điều khiển")) {
      openWindow(id: "main")
      NSApp.activate(ignoringOtherApps: true)
    }
    if !store.presets.isEmpty {
      Menu(L10n.t("menu.applyPreset")) {
        ForEach(store.presets) { preset in
          Button(preset.name + " · " + preset.summary) {
            Task { await store.activate(preset, fanIDs: store.fans.map(\.id)) }
          }
        }
      }.disabled(store.busy || store.fans.isEmpty)
    }
    Button(L10n.t("Tất cả về tự động")) { Task { await store.restoreAll() } }
      .disabled(!store.helperEnabled || store.busy)
    Divider()
    SettingsLink { Text(L10n.t("Cài đặt…")) }
    Button(L10n.t("legal.about")) { openWindow(id: "about"); NSApp.activate(ignoringOtherApps: true) }
    Button(L10n.t("Thoát My Fan Control")) { NSApp.terminate(nil) }.keyboardShortcut("q")
  }
}
