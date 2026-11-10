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
  @State private var menuSession = FanMenuSession()
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
      FanMenu(store: store, session: menuSession)
        .id(language)
    } label: {
      MenuBarLabel(store: store, session: menuSession).task { delegate.store = store; menuSession.bind(store); store.start() }
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
  var session: FanMenuSession? = nil
  @AppStorage("fahrenheit") private var fahrenheit = false
  @AppStorage("menuBarSensorID") private var sensorID = ""
  @AppStorage("menuBarShowRPM") private var showRPM = false
  @AppStorage("menuBarRPMMode") private var rpmMode = ""
  private var reading: Snapshot? {
    if let frozen = session?.frozen { return frozen.reading }
    return store.snapshot
  }
  private var sensor: Sensor? {
    let values = reading?.sensors ?? []
    return sensorID.isEmpty ? values.max { $0.celsius < $1.celsius } : values.first { $0.id == sensorID }
  }
  private var label: String {
    let unit: TemperatureUnit = fahrenheit ? .fahrenheit : .celsius
    let text = sensor.map { unit.text($0.celsius, decimals: 0) } ?? "—" + unit.symbol
    let display = MenuBarRPMDisplay.resolve(stored: rpmMode, legacyShowRPM: showRPM)
    guard let rpm = display.readout(reading?.fans ?? []) else { return text }
    return text + " · " + rpm
  }
  var body: some View {
    // MenuBarExtra can apply an icon-only LabelStyle. Use explicit content so
    // the temperature/RPM text remains visible and its width updates with settings.
    HStack(spacing: 4) {
      Image(systemName: "fan")
      Text(label).monospacedDigit()
    }
    .font(.system(size: 12))
    .fixedSize(horizontal: true, vertical: false)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
  }
}

struct FanMenu: View {
  var store: FanStore
  var session: FanMenuSession
  @Environment(\.openWindow) private var openWindow
  @AppStorage("fahrenheit") private var fahrenheit = false
  var body: some View {
    let displayed = session.presentation(store)
    Text("My Fan Control")
    Text(L10n.t("menu.snapshotHint"))
    if let sensor = displayed.hottest {
      Text(L10n.t("Cảm biến nóng nhất") + ": " + (fahrenheit ? TemperatureUnit.fahrenheit : .celsius).text(sensor.celsius))
    }
    ForEach(displayed.fans) { fan in Text("\(fan.name): \(Int(fan.current)) RPM") }
    Divider()
    Button(L10n.t("Mở bảng điều khiển")) {
      openWindow(id: "main")
      NSApp.activate(ignoringOtherApps: true)
    }
    if !displayed.presets.isEmpty {
      Menu(L10n.t("menu.applyPreset")) {
        ForEach(displayed.presets) { preset in
          Button(preset.name + " · " + preset.summary) {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
            Task { await store.activate(preset, fanIDs: store.fans.map(\.id)) }
          }
        }
      }.disabled(displayed.busy || displayed.fans.isEmpty)
    }
    Button(L10n.t("Tất cả về tự động")) { Task { await store.restoreAll() } }
      .disabled(!displayed.helperEnabled || displayed.busy)
    Divider()
    SettingsLink { Text(L10n.t("Cài đặt…")) }
    Button(L10n.t("legal.about")) { openWindow(id: "about"); NSApp.activate(ignoringOtherApps: true) }
    Button(L10n.t("Thoát My Fan Control")) { NSApp.terminate(nil) }.keyboardShortcut("q")
  }
}
