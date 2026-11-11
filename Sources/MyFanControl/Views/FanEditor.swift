import FanCore
import SwiftUI

struct FanEditor: View {
  var store: FanStore
  var fan: Fan
  @State private var draft = FanPreset(name: "", mode: .automatic)
  @State private var applyAll = false
  @State private var showUnknownSensors = false
  @AppStorage("fahrenheit") private var fahrenheit = false
  private var sensorGroups: [SensorPickerGroup] {
    SensorPickerGroup.make(store.sensors, selectedID: draft.sensor, includeUnknown: showUnknownSensors)
  }
  private var targetFans: [Fan] { applyAll ? store.fans : [fan] }
  private var saved: FanPreset? { store.presets.first(where: { $0.id == draft.id }) }
  private var unchanged: Bool { saved == draft }
  private var draftStatus: FanEditorDraftStatus {
    FanEditorDraftStatus.resolve(draft: draft, saved: saved, applied: applied,
      busy: store.busy, authorizing: store.authorizing,
      restoring: targetFans.contains(where: { store.restoring.contains($0.id) }), valid: validation == nil)
  }
  private var limits: ClosedRange<Double> {
    let low = targetFans.map(\.minimum).max() ?? fan.minimum
    let high = targetFans.map(\.maximum).min() ?? fan.maximum
    return low...max(low + 1, high)
  }
  private var validation: String? {
    do {
      if applyAll, draft.mode == .fixed,
        (targetFans.map(\.minimum).max() ?? 0) >= (targetFans.map(\.maximum).min() ?? 0)
      {
        return L10n.t("group.noCommon")
      }
      for target in targetFans {
        _ = try draft.target(
          for: target, sensors: store.sensors)
      }
      return nil
    } catch { return error.localizedDescription }
  }
  private var applied: Bool {
    guard !targetFans.isEmpty else { return false }
    if draft.mode == .automatic {
      return targetFans.allSatisfy { !$0.manual && !store.controlled.contains($0.id) && !store.restoring.contains($0.id) }
    }
    return targetFans.allSatisfy { store.active[$0.id] == draft && store.controlled.contains($0.id) && !store.restoring.contains($0.id) }
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      SavedPresetList(
        store: store, selectedID: draft.mode == .automatic ? nil : draft.id,
        fanIDs: targetFans.map(\.id), select: load, newPreset: newPreset).disabled(store.busy)
      Picker(L10n.t("preset.target"), selection: $applyAll) {
        Text(fan.name).tag(false)
        if store.fans.count > 1 { Text(L10n.t("preset.allFans")).tag(true) }
      }.pickerStyle(.segmented).disabled(store.busy)
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          Text(L10n.t("mode.draft")).font(.caption).foregroundStyle(.secondary)
          Picker(L10n.t("mode.draft"), selection: $draft.mode) {
            Text(L10n.t("Tự động")).tag(FanPreset.Mode.automatic)
            Text(L10n.t("RPM cố định")).tag(FanPreset.Mode.fixed)
            Text(L10n.t("Cảm biến")).tag(FanPreset.Mode.sensor)
          }.labelsHidden().pickerStyle(.segmented)
          if draft.mode != .automatic {
            TextField(L10n.t("Tên preset để lưu"), text: $draft.name).textFieldStyle(.roundedBorder)
          }
          switch draft.mode {
          case .automatic:
            Text(L10n.t("Giao quyền điều chỉnh tốc độ cho macOS.")).font(.callout).foregroundStyle(
              .secondary)
          case .fixed:
            HStack {
              Text(L10n.t("Tốc độ mục tiêu"))
              Spacer()
              TextField("RPM", value: $draft.rpm, format: .number.precision(.fractionLength(0)))
                .frame(width: 80).textFieldStyle(.roundedBorder)
              Text("RPM").foregroundStyle(.secondary)
            }
            Slider(value: $draft.rpm, in: limits, step: 50) { Text(L10n.t("RPM mục tiêu")) }
            HStack {
              Text("\(Int(limits.lowerBound)) RPM")
              Spacer()
              Text("\(Int(limits.upperBound)) RPM")
            }.font(.caption).foregroundStyle(.secondary)
          case .sensor:
            Picker(L10n.t("Cảm biến"), selection: $draft.sensor) {
              Text(L10n.t("Chọn cảm biến")).tag("")
              Text(L10n.t("sensor.hottest")).tag(FanPreset.hottestSensorID)
              ForEach(sensorGroups) { group in
                Section(group.component.title) {
                  ForEach(group.sensors) { sensor in
                    Text(SensorPickerGroup.label(sensor)).tag(sensor.id)
                  }
                }
              }
              if !draft.sensor.isEmpty, !draft.followsHottestSensor, !store.sensors.contains(where: { $0.id == draft.sensor }) {
                Text(L10n.f("settings.sensorUnavailable", draft.sensor)).tag(draft.sensor)
              }
            }
            if draft.followsHottestSensor {
              Text(L10n.t("sensor.hottestHint")).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
              if let sensor = draft.resolvedSensor(in: store.sensors) {
                let unit: TemperatureUnit = fahrenheit ? .fahrenheit : .celsius
                Text(L10n.f("sensor.hottestCurrent", SensorPickerGroup.label(sensor), unit.text(sensor.celsius)))
                  .font(.caption).monospacedDigit().textSelection(.enabled)
                  .fixedSize(horizontal: false, vertical: true)
              }
            } else {
              Toggle(L10n.t("sensors.showUnknown"), isOn: $showUnknownSensors).font(.caption)
            }
            HStack {
              Text(L10n.t("Bắt đầu tăng"))
              Spacer()
              TextField("°C", value: $draft.start, format: .number).frame(width: 50)
              Text("°C")
            }
            HStack {
              Text(L10n.t("Đạt tối đa"))
              Spacer()
              TextField("°C", value: $draft.full, format: .number).frame(width: 50)
              Text("°C")
            }
            Text(L10n.t("Tăng tuyến tính từ RPM tối thiểu đến tối đa giữa hai ngưỡng.")).font(
              .caption
            ).foregroundStyle(.secondary)
          }
          if let validation {
            Label(validation, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(
              .orange)
          }
          if draftStatus == .unsavedPreset {
            Text(L10n.t("preset.unsaved")).font(.caption).foregroundStyle(.orange)
          } else if draftStatus == .automaticPending || draftStatus == .manualPending {
            Text(L10n.t("mode.pending")).font(.caption).foregroundStyle(.secondary)
          }
        }.padding(.vertical, 2)
      }.frame(minHeight: 80, maxHeight: .infinity).disabled(store.busy || draftStatus == .restoring)
      Divider()
      if draft.mode != .automatic {
        HStack {
          Button(saved == nil ? L10n.t("Lưu preset") : L10n.t("preset.update")) { save() }
            .disabled(store.busy || validation != nil || unchanged)
          if saved != nil {
            Button(L10n.t("preset.copy")) {
              var copy = draft
              copy.id = UUID()
              copy.name = store.uniquePresetName(L10n.f("preset.copyName", draft.name))
              if let value = store.save(copy) { draft = value }
            }.disabled(store.busy || validation != nil)
          }
          Spacer()
        }
      }
      Button {
        apply()
      } label: {
        HStack {
          if draftStatus.inProgress {
            ProgressView().controlSize(.small)
          } else {
            Image(systemName: draftStatus.isApplied ? "checkmark.circle.fill" : (store.helperEnabled ? "fan.fill" : "lock.open"))
          }
          Text(applyTitle)
          Spacer()
        }.frame(maxWidth: .infinity).padding(.vertical, 3)
      }.buttonStyle(.borderedProminent)
        .disabled(store.busy || validation != nil || draftStatus.isApplied || draftStatus == .restoring)
      if !draftStatus.isApplied, !draftStatus.inProgress {
        Text(store.helperEnabled ? L10n.t("preset.applyHint") : L10n.t("preset.permissionHint"))
          .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      }
    }
    .onAppear {
      if let active = store.active[fan.id] {
        draft = active
      } else if let first = store.presets.first {
        draft = first
      } else {
        draft = FanPreset(
          name: L10n.t("Tự động"), mode: .automatic, rpm: min(fan.maximum, max(fan.minimum, 2500)),
          sensor: store.preferredSensorID)
      }
    }
    .onChange(of: applyAll) { _, _ in
      if draft.mode == .fixed {
        draft.rpm = min(limits.upperBound, max(limits.lowerBound, draft.rpm))
      }
    }
    .onChange(of: draft.mode) { old, new in
      if new == .sensor, draft.sensor.isEmpty { draft.sensor = store.preferredSensorID }
      if old == .automatic, new != .automatic, saved == nil {
        draft.name = store.uniquePresetName(L10n.t("preset.newDefault"))
        draft.sensor = store.preferredSensorID
      }
    }
  }
  private var applyTitle: String {
    switch draftStatus {
    case .authorizing: return L10n.t("mode.authorizing")
    case .applying: return L10n.t("mode.applying")
    case .restoring: return L10n.t("schedule.restorePending")
    case .invalid: return L10n.t("mode.review")
    case .automaticApplied, .manualApplied: return L10n.t("mode.applied")
    case .automaticPending:
      return applyAll ? L10n.t("mode.returnAllAuto") : L10n.f("mode.returnFanAuto", fan.name)
    case .unsavedPreset: return L10n.t("preset.saveApply")
    case .manualPending:
      return applyAll ? L10n.t("group.apply") : L10n.f("preset.applyFan", fan.name)
    }
  }
  private func load(_ preset: FanPreset) {
    draft = preset
    store.error = nil
    store.operationMessage = nil
  }
  private func newPreset() {
    draft = FanPreset(
      name: store.uniquePresetName(L10n.t("preset.newDefault")), mode: .fixed,
      rpm: min(limits.upperBound, max(limits.lowerBound, 2500)), sensor: store.preferredSensorID)
    store.error = nil
    store.operationMessage = nil
  }
  private func save() {
    if let value = store.save(draft) { draft = value }
  }
  private func apply() {
    var selected = draft
    if draft.mode != .automatic, !unchanged {
      guard let value = store.save(draft) else { return }
      draft = value
      selected = value
    }
    let ids = targetFans.map(\.id)
    Task { await store.activate(selected, fanIDs: ids) }
  }
}
