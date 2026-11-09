import FanCore
import SwiftUI

struct ScheduleDashboard: View {
  var store: FanStore
  @Environment(\.dismiss) private var dismiss
  @State private var editor: ScheduleEditorRequest?
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Label(L10n.t("schedule.title"), systemImage: "calendar.badge.clock").font(
          .title2.weight(.semibold))
        Spacer()
        Button(L10n.t("schedule.new")) {
          editor = ScheduleEditorRequest(schedule: nil)
        }.disabled(store.presets.filter { $0.mode != .automatic }.isEmpty || store.fans.isEmpty)
        Button(L10n.t("schedule.close")) { dismiss() }.keyboardShortcut(.cancelAction)
      }
      Text(L10n.t("schedule.requirements")).font(.callout).foregroundStyle(.secondary)
      if !store.helperEnabled {
        Button(L10n.t("Bật điều khiển…")) { Task { await store.enable() } }.disabled(store.busy)
      }
      if let error = store.error { Text(error).font(.callout).foregroundStyle(.orange) }
      if store.presets.filter({ $0.mode != .automatic }).isEmpty {
        Text(L10n.t("schedule.needPreset")).font(.callout).foregroundStyle(.orange)
      }
      if let error = store.schedules.error { Text(error).font(.callout).foregroundStyle(.orange) }
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          if store.schedules.items.isEmpty {
            ContentUnavailableView(L10n.t("schedule.empty"), systemImage: "timer")
          }
          ForEach(store.schedules.items) { item in
            ScheduleRow(item: item, run: store.schedules.running[item.id], store: store) {
              editor = ScheduleEditorRequest(schedule: item)
            }
          }
          if !store.schedules.events.isEmpty {
            Divider()
            Text(L10n.t("schedule.activity")).font(.headline)
            ForEach(store.schedules.events.prefix(10)) { event in
              HStack(alignment: .top) {
                Text(event.date, style: .time).font(.caption.monospacedDigit()).foregroundStyle(
                  .secondary)
                Text(L10n.f(event.key, event.name)).font(.caption)
              }
            }
          }
        }.frame(maxWidth: .infinity, alignment: .leading)
      }
      Text(L10n.f("schedule.timezone", TimeZone.current.identifier)).font(.caption).foregroundStyle(
        .secondary)
    }.padding(24).frame(width: 740, height: 640)
      .sheet(item: $editor) { request in ScheduleEditor(store: store, existing: request.schedule) }
  }
}

struct ScheduleRow: View {
  var item: FanSchedule
  var run: ScheduledRun?
  var store: FanStore
  var edit: () -> Void
  private var timing: String {
    switch item.timing {
    case .once(let date):
      return date.formatted(
        .dateTime.day().month().year().hour().minute().locale(Locale(identifier: L10n.language)))
    case .weekly(let days, let hour, let minute):
      var calendar = Calendar.current
      calendar.locale = Locale(identifier: L10n.language)
      return days.sorted().map { calendar.shortWeekdaySymbols[$0 - 1] }.joined(separator: ", ")
        + String(format: " · %02d:%02d", hour, minute)
    }
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Toggle(
          item.name,
          isOn: Binding(get: { item.enabled }, set: { enabled in Task { await store.schedules.changeEnabled(item.id, enabled, store: store) } })
        ).fontWeight(.semibold).disabled(store.busy)
        Spacer()
        Button(L10n.t("schedule.edit"), action: edit)
        Button(role: .destructive) {
          Task { await store.schedules.delete(item.id, store: store) }
        } label: {
          Image(systemName: "trash")
        }
        .accessibilityLabel(L10n.t("schedule.delete"))
      }
      Text(
        timing + " · " + item.preset.name + " · " + L10n.f("schedule.minutes", item.durationMinutes)
      ).font(.callout)
      Text(
        item.fanIDs.map { fanID in
          store.fans.first(where: { $0.id == fanID })?.name ?? L10n.f("fan.name", fanID + 1)
        }.joined(separator: ", ")
      ).font(.caption).foregroundStyle(.secondary)
      if let run {
        HStack {
          Label(L10n.t(run.stopping ? "schedule.restorePending" : "schedule.running"), systemImage: "timer").foregroundStyle(.green)
          if !run.stopping { Text(run.endsAt, style: .timer).monospacedDigit() }
          Spacer()
          Button(L10n.t("schedule.cancel")) {
            Task { await store.schedules.cancel(item.id, store: store) }
          }
        }.font(.callout)
      } else if item.enabled, let next = item.nextFire(after: Date()) {
        Text(
          L10n.f(
            "schedule.next",
            next.formatted(
              .dateTime.day().month().hour().minute().locale(Locale(identifier: L10n.language))))
        ).font(.caption).foregroundStyle(.secondary)
      }
    }.padding(14).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
  }
}

private struct ScheduleEditorRequest: Identifiable {
  let id = UUID()
  var schedule: FanSchedule?
}
