import AppKit
import FanCore
import SwiftUI

struct SettingsView: View {
  var store: FanStore
  var updates: UpdateStore
  var body: some View {
    TabView {
      GeneralSettingsView(store: store).tabItem { Label(L10n.t("settings.general"), systemImage: "gearshape") }
      DataSettingsView(store: store).tabItem { Label(L10n.t("settings.data"), systemImage: "externaldrive") }
      SupportSettingsView(store: store, updates: updates).tabItem { Label(L10n.t("settings.support"), systemImage: "questionmark.circle") }
    }.padding(16).frame(width: 620, height: 530)
  }
}

struct GeneralSettingsView: View {
  var store: FanStore
  @AppStorage("language") private var language = "system"
  @AppStorage("fahrenheit") private var fahrenheit = false
  @AppStorage("menuBarSensorID") private var menuBarSensorID = ""
  @AppStorage("menuBarShowRPM") private var showRPM = false
  @AppStorage("menuBarRPMMode") private var rpmMode = ""
  private var rpmSelection: Binding<MenuBarRPMDisplay> {
    Binding(get: { MenuBarRPMDisplay.resolve(stored: rpmMode, legacyShowRPM: showRPM) },
      set: { value in rpmMode = value.rawValue; showRPM = value != .hidden })
  }
  @AppStorage("historyMinutes") private var historyMinutes = 10
  @State private var login = LoginItemController()
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Picker(L10n.t("language"), selection: $language) {
          Text(L10n.t("language.system")).tag("system")
          Text("Tiếng Việt").tag("vi")
          Text("English").tag("en")
        }.pickerStyle(.segmented)
        Toggle(L10n.t("Hiển thị cảm biến bằng °F"), isOn: $fahrenheit)
        LabeledContent(L10n.t("Cập nhật"), value: L10n.t("Mỗi 1 giây"))
        Divider()
        MinimumRPMSettings(store: store)
        Divider()
        FanProtectionSettings(store: store)
        Divider()
        Picker(L10n.t("settings.menuSensor"), selection: $menuBarSensorID) {
          Text(L10n.t("Cảm biến nóng nhất")).tag("")
          ForEach(store.sensors) { sensor in Text(sensor.name + " · " + sensor.id).tag(sensor.id) }
          if !menuBarSensorID.isEmpty, !store.sensors.contains(where: { $0.id == menuBarSensorID }) {
            Text(L10n.f("settings.sensorUnavailable", menuBarSensorID)).tag(menuBarSensorID)
          }
        }
        Picker(L10n.t("settings.menuRPMMode"), selection: rpmSelection) {
          ForEach(MenuBarRPMDisplay.allCases, id: \.rawValue) { mode in Text(mode.title).tag(mode) }
        }.pickerStyle(.segmented)
        HStack(spacing: 12) {
          Text(L10n.t("settings.menuPreview")).font(.caption).foregroundStyle(.secondary)
          ScrollView(.horizontal, showsIndicators: false) { MenuBarLabel(store: store) }.frame(height: 22)
        }
        Picker(L10n.t("settings.history"), selection: $historyMinutes) {
          ForEach([10, 30, 60], id: \.self) { Text(L10n.f("schedule.minutes", $0)).tag($0) }
        }.pickerStyle(.segmented)
        Divider()
        Toggle(L10n.t("settings.login"), isOn: Binding(get: { login.enabled || login.requiresApproval }, set: { login.setEnabled($0) }))
        if login.requiresApproval { Button(L10n.t("settings.loginApproval")) { login.openSettings() } }
        if let error = login.error { Text(error).font(.caption).foregroundStyle(.orange).textSelection(.enabled) }
        Text(L10n.t("settings.loginHint")).font(.caption).foregroundStyle(.secondary)
        Text(L10n.t("Đóng cửa sổ vẫn giữ app trong menu bar. Thoát app sẽ yêu cầu trả quạt về tự động."))
          .font(.caption).foregroundStyle(.secondary)
      }.padding(16)
    }.onAppear { login.refresh() }
  }
}

struct DataSettingsView: View {
  var store: FanStore
  @State private var feedback: String?
  @State private var pendingData: Data?
  @State private var importSummary = ""
  @State private var working = false
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text(L10n.t("backup.title")).font(.headline)
      Text(L10n.t("backup.explanation")).font(.callout).foregroundStyle(.secondary)
      HStack {
        Button(L10n.t("backup.export")) { Task { await exportBackup() } }
        Button(L10n.t("backup.import")) { Task { await prepareImport() } }
      }.disabled(working || store.busy)
      Divider()
      Button(L10n.t("data.exportCSV")) {
        Task {
          guard let snapshot = store.snapshot else { return }
          let unit: TemperatureUnit = UserDefaults.standard.bool(forKey: "fahrenheit") ? .fahrenheit : .celsius
          await save(Data(SensorCSV.export(snapshot, unit: unit).utf8), name: "MyFanControl-sensors.csv", csv: true)
        }
      }.disabled(store.snapshot == nil || working)
      Text(L10n.t("data.csvHint")).font(.caption).foregroundStyle(.secondary)
      Spacer()
      if let feedback { Text(feedback).font(.callout).textSelection(.enabled) }
    }.padding(16)
      .alert(L10n.t("backup.confirm"), isPresented: Binding(get: { pendingData != nil }, set: { if !$0 { pendingData = nil } })) {
        Button(L10n.t("backup.import")) {
          guard let data = pendingData else { return }
          do { try store.importBackup(data); feedback = L10n.t("backup.imported") }
          catch { feedback = error.localizedDescription }
          pendingData = nil
        }
        Button(L10n.t("schedule.close"), role: .cancel) { pendingData = nil }
      } message: { Text(importSummary) }
  }
  private func exportBackup() async {
    do { await save(try store.exportBackup(), name: "MyFanControl-backup.json") }
    catch { feedback = error.localizedDescription }
  }
  private func prepareImport() async {
    working = true
    defer { working = false }
    do {
      guard let data = try await ReleaseFiles.openBackup() else { return }
      let plan = try store.backupPlan(data)
      importSummary = L10n.f("backup.summary", plan.presets.count - store.presets.count, plan.schedules.count - store.schedules.items.count)
      pendingData = data
    } catch { feedback = error.localizedDescription }
  }
  private func save(_ data: Data, name: String, csv: Bool = false) async {
    working = true
    defer { working = false }
    do {
      if try await ReleaseFiles.save(data, name: name, type: csv ? .commaSeparatedText : .json) { feedback = L10n.t("data.saved") }
    } catch { feedback = error.localizedDescription }
  }
}

struct SupportSettingsView: View {
  var store: FanStore
  var updates: UpdateStore
  @State private var working = false
  @State private var feedback: String?
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        UpdateSection(updates: updates)
        Text(L10n.t("diagnostics.title")).font(.headline)
        Text(L10n.t("diagnostics.explanation")).font(.caption).foregroundStyle(.secondary)
        Button {
          working = true
          Task {
            defer { working = false }
            do {
              let data = try await store.diagnosticsData()
              if try await ReleaseFiles.save(data, name: "MyFanControl-diagnostics.json", type: .json) { feedback = L10n.t("data.saved") }
            } catch { feedback = error.localizedDescription }
          }
        } label: { if working { ProgressView().controlSize(.small) } else { Text(L10n.t("diagnostics.export")) } }
          .disabled(working)
        HStack {
          Link(L10n.t("info.reportIssue"), destination: AppMetadata.issuesURL)
          Link(L10n.t("info.guide"), destination: AppMetadata.guideURL)
        }
        if let feedback { Text(feedback).font(.callout).textSelection(.enabled) }
      }.padding(16)
    }
  }
}


private struct MinimumRPMSettings: View {
  var store: FanStore
  @State private var custom = false
  @State private var value = 0.0
  @State private var feedback: String?
  private var selection: Double? { custom ? value : nil }
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(L10n.t("rpm.minimumTitle")).font(.headline)
      Toggle(L10n.t("rpm.customMinimum"), isOn: $custom)
      if custom {
        HStack {
          Text(L10n.t("rpm.minimumTitle"))
          TextField("RPM", value: $value, format: .number.precision(.fractionLength(0)))
            .frame(width: 90).textFieldStyle(.roundedBorder)
          Text("RPM")
          Stepper("RPM", value: $value, in: 0...store.maximumMinimumRPM, step: 50).labelsHidden()
        }
      }
      Text(L10n.t("rpm.minimumHint")).font(.caption).foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Button(L10n.t("rpm.saveMinimum")) {
        Task {
          let saved = await store.setMinimumRPM(selection)
          feedback = saved ? L10n.t("rpm.minimumSaved") : store.error
        }
      }.disabled(store.busy || selection == store.minimumRPM)
      if let feedback { Text(feedback).font(.caption).textSelection(.enabled) }
    }.disabled(store.busy)
      .onAppear { custom = store.minimumRPM != nil; value = store.minimumRPM ?? 0 }
  }
}


private struct FanProtectionSettings: View {
  var store: FanStore
  @State private var feedback: String?
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Toggle(L10n.t("protection.title"), isOn: Binding(
        get: { store.fanProtectionEnabled },
        set: { enabled in
          Task {
            let success = await store.setFanProtection(enabled)
            feedback = success ? L10n.t(enabled ? "protection.enabled" : "protection.disabled") : store.error
          }
        }))
      Text(L10n.t("protection.detail")).font(.caption).foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Text(L10n.t("rpm.softStartHint")).font(.caption).foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      if let feedback { Text(feedback).font(.caption).textSelection(.enabled) }
    }.disabled(store.busy)
  }
}
