import FanCore
import SwiftUI

struct ScheduleEditor: View {
  var store: FanStore
  var existing: FanSchedule?
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var timing = 0
  @State private var minutes = 30
  @State private var countdownMinutes = 5
  @State private var date = Date().addingTimeInterval(3600)
  @State private var time = Date()
  @State private var days: Set<Int> = [2, 3, 4, 5, 6]
  @State private var fanIDs = Set<Int>()
  @State private var presetID: UUID?
  @State private var error: String?
  private var availablePresets: [FanPreset] {
    var presets = store.presets.filter { $0.mode != .automatic }
    if let old = existing?.preset, !presets.contains(where: { $0.id == old.id }) {
      presets.append(old)
    }
    return presets
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text(existing == nil ? L10n.t("schedule.new") : L10n.t("schedule.edit")).font(
        .title2.weight(.semibold))
      Form {
        TextField(L10n.t("schedule.name"), text: $name)
        Picker(L10n.t("schedule.type"), selection: $timing) {
          Text(L10n.t("schedule.countdown")).tag(0)
          Text(L10n.t("schedule.date")).tag(1)
          Text(L10n.t("schedule.weekly")).tag(2)
        }.pickerStyle(.segmented)
        if timing == 0 {
          Stepper(
            L10n.f("schedule.startIn", countdownMinutes), value: $countdownMinutes, in: 0...1440)
        } else if timing == 1 {
          DatePicker(
            L10n.t("schedule.start"), selection: $date, in: Date()...,
            displayedComponents: [.date, .hourAndMinute])
        } else {
          DatePicker(
            L10n.t("schedule.start"), selection: $time, displayedComponents: .hourAndMinute)
          HStack {
            ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
              Toggle(
                weekday(day),
                isOn: Binding(
                  get: { days.contains(day) },
                  set: { if $0 { days.insert(day) } else { days.remove(day) } })
              ).toggleStyle(.button)
            }
          }
        }
        Picker(L10n.t("schedule.preset"), selection: $presetID) {
          ForEach(availablePresets) { preset in Text(preset.name).tag(Optional(preset.id)) }
        }
        Stepper(L10n.f("schedule.duration", minutes), value: $minutes, in: 1...1440)
        HStack {
          Text(L10n.t("schedule.targetFans"))
          ForEach(store.fans) { fan in
            Toggle(
              fan.name,
              isOn: Binding(
                get: { fanIDs.contains(fan.id) },
                set: { if $0 { fanIDs.insert(fan.id) } else { fanIDs.remove(fan.id) } })
            ).toggleStyle(.button)
          }
        }
      }.textFieldStyle(.roundedBorder)
      Text(L10n.t("schedule.finishAuto")).font(.callout).foregroundStyle(.secondary)
      if let error { Text(error).font(.callout).foregroundStyle(.orange) }
      HStack {
        Button(L10n.t("schedule.close")) { dismiss() }.keyboardShortcut(.cancelAction)
        Spacer()
        Button(L10n.t("schedule.save"), action: save).buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
      }
    }.padding(24).frame(width: 620)
      .onAppear {
        fanIDs = Set(store.fans.map(\.id))
        presetID = store.presets.first(where: { $0.mode != .automatic })?.id
        if let item = existing {
          name = item.name
          minutes = item.durationMinutes
          fanIDs = Set(item.fanIDs)
          presetID = item.preset.id
          switch item.timing {
          case .once(let when):
            timing = 1
            date = max(when, Date().addingTimeInterval(60))
          case .weekly(let weekdays, let hour, let minute):
            timing = 2
            days = Set(weekdays)
            time =
              Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
              ?? Date()
          }
        }
      }
  }
  private func weekday(_ day: Int) -> String {
    var calendar = Calendar.current
    calendar.locale = Locale(identifier: L10n.language)
    return calendar.veryShortWeekdaySymbols[day - 1]
  }
  private func save() {
    guard let preset = store.presets.first(where: { $0.id == presetID }) ?? existing?.preset else {
      error = L10n.t("schedule.needPreset")
      return
    }
    let when: FanSchedule.Timing
    if timing == 0 {
      when = .once(Date().addingTimeInterval(Double(countdownMinutes) * 60 + 1))
    } else if timing == 1 {
      when = .once(date)
    } else {
      let fields = Calendar.current.dateComponents([.hour, .minute], from: time)
      when = .weekly(days: days.sorted(), hour: fields.hour ?? 0, minute: fields.minute ?? 0)
    }
    var item = FanSchedule(
      name: name, fanIDs: fanIDs.sorted(), preset: preset, durationMinutes: minutes, timing: when)
    if let existing {
      item.id = existing.id
      item.enabled = existing.enabled
    }
    do {
      try store.schedules.save(item)
      dismiss()
    } catch { self.error = error.localizedDescription }
  }
}
