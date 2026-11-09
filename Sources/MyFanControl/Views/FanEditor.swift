import FanCore
import SwiftUI

struct FanEditor: View {
  var store: FanStore
  var fan: Fan
  @State private var mode = FanPreset.Mode.automatic
  @State private var rpm = 2500.0
  @State private var sensor = ""
  @State private var start = 45.0
  @State private var full = 80.0
  @State private var name = ""
  private var rule: FanPreset {
    FanPreset(
      name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? title : name,
      mode: mode, rpm: rpm, sensor: sensor, start: start, full: full)
  }
  private var title: String {
    mode == .automatic
      ? L10n.t("Tự động") : mode == .fixed ? L10n.t("RPM cố định") : L10n.t("Theo cảm biến")
  }
  private var validation: String? {
    do {
      _ = try rule.target(
        for: fan, temperature: store.sensors.first(where: { $0.id == sensor })?.celsius)
      return nil
    } catch { return error.localizedDescription }
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text(L10n.f("editor.title", fan.name.lowercased())).font(.headline)
        Spacer()
        Menu {
          if store.presets.isEmpty { Text(L10n.t("Chưa lưu preset")) }
          ForEach(store.presets) { preset in
            Button(preset.name) { load(preset) }
          }
          if !store.presets.isEmpty {
            Divider()
            Menu(L10n.t("Xóa preset")) {
              ForEach(store.presets) { preset in
                Button(preset.name, role: .destructive) { store.deletePreset(preset.id) }
              }
            }
          }
        } label: {
          Label("Preset", systemImage: "slider.horizontal.3")
        }
      }
      Picker(L10n.t("Chế độ"), selection: $mode) {
        Text(L10n.t("Tự động")).tag(FanPreset.Mode.automatic)
        Text(L10n.t("RPM cố định")).tag(FanPreset.Mode.fixed)
        Text(L10n.t("Cảm biến")).tag(FanPreset.Mode.sensor)
      }.pickerStyle(.segmented)
      switch mode {
      case .automatic:
        Text(L10n.t("Giao quyền điều chỉnh tốc độ cho macOS.")).foregroundStyle(.secondary).font(
          .callout)
      case .fixed:
        HStack {
          Text(L10n.t("Tốc độ mục tiêu"))
          Spacer()
          Text("\(Int(rpm)) RPM").monospacedDigit().fontWeight(.medium)
        }
        Slider(value: $rpm, in: fan.minimum...fan.maximum, step: 50) {
          Text(L10n.t("RPM mục tiêu"))
        }
        HStack {
          Text("\(Int(fan.minimum)) RPM")
          Spacer()
          Text("\(Int(fan.maximum)) RPM")
        }.font(.caption).foregroundStyle(.secondary)
      case .sensor:
        Picker(L10n.t("Cảm biến"), selection: $sensor) {
          Text(L10n.t("Chọn cảm biến")).tag("")
          ForEach(store.sensors) { s in
            Text("\(s.name) · \(String(format:"%.0f°C",s.celsius))").tag(s.id)
          }
        }
        HStack {
          Text(L10n.t("Bắt đầu tăng")).font(.callout)
          Spacer()
          TextField("°C", value: $start, format: .number).frame(width: 48)
          Text("°C").foregroundStyle(.secondary)
        }
        HStack {
          Text(L10n.t("Đạt tối đa")).font(.callout)
          Spacer()
          TextField("°C", value: $full, format: .number).frame(width: 48)
          Text("°C").foregroundStyle(.secondary)
        }
        Text(L10n.t("Tăng tuyến tính từ RPM tối thiểu đến tối đa giữa hai ngưỡng.")).font(.caption)
          .foregroundStyle(.secondary)
      }
      if let validation { Text(validation).font(.caption).foregroundStyle(.orange) }
      if mode != .automatic {
        TextField(L10n.t("Tên preset để lưu"), text: $name).textFieldStyle(.roundedBorder)
      }
      HStack {
        if mode != .automatic {
          Button(L10n.t("Lưu preset")) { store.save(rule) }.disabled(
            validation != nil || store.presets.count >= 50)
        }
        Spacer()
        Button(L10n.t("Áp dụng cho quạt này")) { Task { await store.apply(rule, to: fan.id) } }
          .buttonStyle(.borderedProminent).disabled(
            !store.helperEnabled || store.busy || validation != nil)
      }
      if !store.helperEnabled {
        Text(L10n.t("Bấm “Bật điều khiển…” để macOS hỏi quyền quản trị khi bạn muốn áp dụng."))
          .font(.caption).foregroundStyle(.secondary)
      }
    }.textFieldStyle(.roundedBorder)
      .onAppear {
        rpm = min(fan.maximum, max(fan.minimum, 2500))
        sensor = store.hottest?.id ?? ""
        if let current = store.active[fan.id] { load(current) }
      }
  }
  private func load(_ preset: FanPreset) {
    mode = preset.mode
    rpm = preset.rpm
    sensor = preset.sensor
    start = preset.start
    full = preset.full
    name = preset.name
  }
}
