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
  @State private var presetID: String?
  @State private var error: String?
  @State private var enabled = true
  private var availablePresets: [SchedulePresetChoice] {
    SchedulePresetChoice.make(library: store.presets, saved: existing?.preset)
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Label(
        existing == nil ? L10n.t("schedule.new") : L10n.t("schedule.edit"),
        systemImage: "calendar.badge.clock"
      )
      .font(.title2.weight(.semibold))
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          field(L10n.t("schedule.name")) {
            TextField(L10n.t("schedule.name"), text: $name).labelsHidden().textFieldStyle(
              .roundedBorder)
          }
          field(L10n.t("schedule.type")) {
            Picker(L10n.t("schedule.type"), selection: $timing) {
              Text(L10n.t("schedule.countdown")).tag(0)
              Text(L10n.t("schedule.date")).tag(1)
              Text(L10n.t("schedule.weekly")).tag(2)
            }.labelsHidden().pickerStyle(.segmented)
          }
          if timing == 0 {
            field(L10n.t("schedule.delay")) {
              VStack(alignment: .leading, spacing: 6) {
                minuteInput($countdownMinutes, range: 0...1440)
                Text(L10n.t("schedule.zeroNow")).font(.caption).foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
          } else if timing == 1 {
            field(L10n.t("schedule.start")) {
              DatePicker(
                L10n.t("schedule.start"), selection: $date,
                displayedComponents: [.date, .hourAndMinute]
              ).labelsHidden()
            }
          } else {
            field(L10n.t("schedule.start")) {
              DatePicker(
                L10n.t("schedule.start"), selection: $time, displayedComponents: .hourAndMinute
              ).labelsHidden()
            }
            field(L10n.t("schedule.weekly")) {
              HStack(spacing: 6) {
                ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                  Toggle(
                    weekday(day),
                    isOn: Binding(
                      get: { days.contains(day) },
                      set: { if $0 { days.insert(day) } else { days.remove(day) } })
                  )
                  .toggleStyle(.button).controlSize(.small)
                }
              }
            }
          }
          field(L10n.t("schedule.preset")) {
            Picker(L10n.t("schedule.preset"), selection: $presetID) {
              ForEach(availablePresets) { choice in
                Text(choice.preset.name + (choice.isSnapshot ? " · " + L10n.t("schedule.savedSnapshot") : ""))
                  .tag(Optional(choice.id))
              }
            }.labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
          }
          field(L10n.t("schedule.runDuration")) { minuteInput($minutes, range: 1...1440) }
          field(L10n.t("schedule.targetFans")) {
            HStack(spacing: 8) {
              ForEach(store.fans) { fan in
                Toggle(
                  fan.name,
                  isOn: Binding(
                    get: { fanIDs.contains(fan.id) },
                    set: { if $0 { fanIDs.insert(fan.id) } else { fanIDs.remove(fan.id) } })
                ).toggleStyle(.button)
              }
            }
          }
          field("") { Toggle(L10n.t("schedule.enabled"), isOn: $enabled) }
        }.padding(.vertical, 3)
      }.frame(maxWidth: .infinity, maxHeight: .infinity)
      Text(L10n.t("schedule.finishAuto")).font(.caption).foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true).frame(
          maxWidth: .infinity, alignment: .leading)
      if let error {
        Label(error, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
      Divider()
      HStack {
        Button(L10n.t("schedule.close")) { dismiss() }.keyboardShortcut(.cancelAction)
        Spacer()
        Button(L10n.t("schedule.save"), action: save).buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
      }
    }.padding(24).frame(width: 680, height: 620)
      .onAppear(perform: load)
  }
  private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    HStack(alignment: .top, spacing: 16) {
      Text(title).font(.callout).foregroundStyle(.secondary).frame(width: 126, alignment: .leading)
        .padding(.top, 5)
        .fixedSize(horizontal: false, vertical: true)
      content().frame(maxWidth: .infinity, alignment: .leading)
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
  private func minuteInput(_ value: Binding<Int>, range: ClosedRange<Int>) -> some View {
    HStack(spacing: 10) {
      TextField(
        L10n.t("schedule.minuteUnit"), value: value, format: .number.precision(.fractionLength(0))
      )
      .textFieldStyle(.roundedBorder).frame(width: 80)
      Text(L10n.t("schedule.minuteUnit")).font(.callout).foregroundStyle(.secondary)
      Stepper("", value: value, in: range).labelsHidden().fixedSize()
      Spacer(minLength: 0)
    }
  }
  private func weekday(_ day: Int) -> String {
    var calendar = Calendar.current
    calendar.locale = Locale(identifier: L10n.language)
    return calendar.shortWeekdaySymbols[day - 1]
  }
  private func load() {
    fanIDs = Set(store.fans.map(\.id))
    presetID = availablePresets.first?.id
    guard let item = existing else { return }
    enabled = item.enabled
    name = item.name
    minutes = item.durationMinutes
    fanIDs = Set(item.fanIDs)
    presetID = availablePresets.first(where: { $0.isSnapshot })?.id ?? item.preset.id.uuidString
    switch item.timing {
    case .once(let when):
      timing = 1
      date = when
    case .weekly(let weekdays, let hour, let minute):
      timing = 2
      days = Set(weekdays)
      time =
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
  }
  private func save() {
    guard let preset = availablePresets.first(where: { $0.id == presetID })?.preset else {
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
    guard (0...1440).contains(countdownMinutes) else {
      error = L10n.t("schedule.invalid")
      return
    }
    var item = FanSchedule(
      name: name, fanIDs: fanIDs.sorted(), preset: preset, durationMinutes: minutes, timing: when)
    if let existing { item.id = existing.id }
    item.enabled = enabled
    do {
      try store.schedules.save(item)
      dismiss()
    } catch { self.error = error.localizedDescription }
  }
}
