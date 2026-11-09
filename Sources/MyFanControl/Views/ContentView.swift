import Charts
import FanCore
import SwiftUI

struct ContentView: View {
  var store: FanStore
  @Environment(\.openWindow) private var openWindow
  @State private var search = ""
  @State private var selectedSensor: String?
  @State private var showUnknown = false
  @State private var showSchedules = false
  @AppStorage("fahrenheit") private var fahrenheit = false
  @AppStorage("historyMinutes") private var historyMinutes = 10
  private var unit: TemperatureUnit { fahrenheit ? .fahrenheit : .celsius }
  private var visibleHistory: [TemperaturePoint] {
    let window = [10, 30, 60].contains(historyMinutes) ? historyMinutes : 10
    let cutoff = Date().addingTimeInterval(-Double(window) * 60)
    return store.history.filter { $0.date >= cutoff }
  }
  private var visibleSensors: [Sensor] {
    store.sensors.filter { sensor in
      let info = SensorCatalog.lookup(sensor.id)
      return (showUnknown || info.known)
        && (search.isEmpty || sensor.name.localizedCaseInsensitiveContains(search)
          || sensor.id.localizedCaseInsensitiveContains(search)
          || info.component.title.localizedCaseInsensitiveContains(search))
    }
  }
  var body: some View {
    VStack(spacing: 0) {
      overview.padding(24)
      if let message = store.error ?? store.helperMessage ?? store.telemetryError {
        Label(message, systemImage: "exclamationmark.triangle.fill")
          .font(.callout).foregroundStyle(.orange).textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(
            .bottom, 16)
      }
      if let message = store.operationMessage, store.error == nil {
        Label(message, systemImage: "checkmark.circle.fill").font(.callout).foregroundStyle(.green)
          .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(
            .bottom, 12)
      }
      HSplitView {
        VStack(alignment: .leading, spacing: 12) {
          Label(L10n.t("ĐIỀU KHIỂN QUẠT"), systemImage: "fan").font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          if store.fans.isEmpty {
            ContentUnavailableView(
              L10n.t(store.snapshot?.fanAvailability == .noneReported
                ? "compat.noFans" : "Chưa có dữ liệu quạt"), systemImage: "fan.slash",
              description: Text(L10n.t(store.snapshot?.fanAvailability == .noneReported
                ? "compat.noFansDetail" : "compat.unavailableFans")))
          } else {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 8) {
                ForEach(store.fans) { fan in
                  Button {
                    store.selectedFan = fan.id
                  } label: {
                    VStack(alignment: .leading, spacing: 4) {
                      Text(fan.name).font(.callout.weight(.semibold))
                      Text("\(Int(fan.current)) RPM").font(.system(.title3, design: .rounded))
                        .monospacedDigit()
                      Text(
                        store.active[fan.id]?.name
                          ?? (fan.manual ? L10n.t("Thủ công") : L10n.t("Tự động"))
                      ).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }.frame(minWidth: 135, maxWidth: .infinity, alignment: .leading).padding(10)
                      .background(
                        store.selectedFan == fan.id
                          ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 8)
                      )
                      .overlay(
                        RoundedRectangle(cornerRadius: 8).stroke(
                          store.selectedFan == fan.id ? Color.accentColor.opacity(0.5) : .clear))
                  }.buttonStyle(.plain)
                }
              }
            }.fixedSize(horizontal: false, vertical: true)
            if let fan = store.fans.first(where: { $0.id == store.selectedFan }) {
              FanEditor(store: store, fan: fan)
            }
          }
        }.padding(20).frame(minWidth: 390, idealWidth: 450, maxWidth: 520)
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Label(L10n.t("CẢM BIẾN NHIỆT"), systemImage: "thermometer.medium").font(
              .caption.weight(.semibold)
            ).foregroundStyle(.secondary)
            Spacer()
            Text(L10n.f("sensors.count", store.sensors.count)).font(.caption).foregroundStyle(
              .secondary)
          }
          TextField(L10n.t("Tìm cảm biến hoặc SMC key"), text: $search).textFieldStyle(
            .roundedBorder)
          Toggle(L10n.t("sensors.showUnknown"), isOn: $showUnknown).font(.caption)
          Table(visibleSensors, selection: $selectedSensor) {
            TableColumn(L10n.t("Cảm biến")) { sensor in Text(sensor.name) }.width(
              min: 130, ideal: 180)
            TableColumn(L10n.t("sensors.module")) { sensor in
              Text(SensorCatalog.lookup(sensor.id).component.title).font(.caption).foregroundStyle(
                .secondary)
            }.width(85)
            TableColumn("Key") { sensor in
              Text(sensor.id).font(.system(.caption, design: .monospaced)).foregroundStyle(
                .secondary)
            }.width(55)
            TableColumn(fahrenheit ? "°F" : "°C") { sensor in
              Text(String(format: "%.1f", unit.value(sensor.celsius)))
                .monospacedDigit().foregroundStyle(sensor.celsius >= 80 ? .orange : .primary)
            }.width(60)
          }.frame(minHeight: 160)
          if let sensor = store.sensors.first(where: { $0.id == selectedSensor })
            ?? visibleSensors.first
          {
            SensorDetailView(sensor: sensor)
          }
          history.frame(height: 100)
        }.padding(20).frame(minWidth: 440, maxWidth: .infinity)
      }
      Divider()
      HStack(spacing: 8) {
        Circle().fill(store.snapshot == nil ? Color.orange : Color.green).frame(width: 6, height: 6)
        Text(
          store.lastRead.map {
            L10n.f("status.updated", $0.formatted(date: .omitted, time: .standard))
          } ?? L10n.t("Đang kết nối AppleSMC…"))
        Spacer()
        Text(
          store.helperEnabled
            ? L10n.t("Quyền điều khiển đã bật") : L10n.t("Chỉ theo dõi · chưa thay đổi tốc độ quạt")
        )
      }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 24).padding(.vertical, 12)
    }
    .toolbar {
      ToolbarItemGroup {
        Button { openWindow(id: "about") } label: {
          Label(L10n.t("legal.about"), systemImage: "info.circle")
        }
        SettingsLink { Label(L10n.t("Cài đặt…"), systemImage: "gearshape") }
        Button {
          showSchedules = true
        } label: {
          Label(L10n.t("schedule.title"), systemImage: "calendar.badge.clock")
        }
        Button {
          Task { await store.restoreAll() }
        } label: {
          Label(L10n.t("Tất cả tự động"), systemImage: "arrow.uturn.backward")
        }
        .disabled(!store.helperEnabled || store.busy)
        if !store.helperEnabled {
          Button {
            Task { await store.enable() }
          } label: {
            Label(L10n.t("Bật điều khiển…"), systemImage: "lock.open")
          }
          .disabled(store.busy || store.fans.isEmpty)
        } else {
          Button {
            Task { await store.shutdown() }
          } label: {
            Label(L10n.t("Tắt điều khiển"), systemImage: "lock")
          }.disabled(store.busy)
        }
      }
    }
    .sheet(isPresented: $showSchedules) { ScheduleDashboard(store: store) }
  }
  private var overview: some View {
    HStack(alignment: .center, spacing: 24) {
      Image(nsImage: AppIdentity.icon).resizable().frame(width: 54, height: 54)
      VStack(alignment: .leading, spacing: 4) {
        Text("My Fan Control").font(.title2.weight(.semibold))
        Text(L10n.t("Nhiệt độ rõ ràng. Làm mát theo cách của bạn.")).font(.callout).foregroundStyle(
          .secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        Text(
          store.hottest.map {
            String(
              format: "%.1f%@", fahrenheit ? $0.celsius * 1.8 + 32 : $0.celsius,
              fahrenheit ? "°F" : "°C")
          } ?? "—"
        )
        .font(.system(size: 30, weight: .medium, design: .rounded)).monospacedDigit()
        Text(L10n.t("Cảm biến nóng nhất")).font(.caption).foregroundStyle(.secondary)
      }
      Divider().frame(height: 42)
      VStack(alignment: .trailing, spacing: 4) {
        Text(
          store.snapshot == nil
            ? L10n.t("Chưa kết nối")
            : store.controlled.isEmpty
              ? (store.fans.contains(where: { $0.manual }) ? L10n.t("Thủ công") : L10n.t("Tự động"))
              : L10n.t("Tùy chỉnh")
        ).font(.title3.weight(.medium))
        Text(
          store.snapshot == nil
            ? L10n.t("Đang chờ dữ liệu")
            : store.controlled.isEmpty
              ? (store.fans.contains(where: { $0.manual })
                ? L10n.t("Ngoài phiên điều khiển này") : L10n.t("macOS quản lý quạt"))
              : L10n.f("status.controlled", store.controlled.count)
        )
        .font(.caption).foregroundStyle(.secondary)
      }
    }
  }
  private var history: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(L10n.f("history.title", historyMinutes)).font(.caption).foregroundStyle(.secondary)
      Chart(visibleHistory) { point in
        AreaMark(x: .value(L10n.t("Thời gian"), point.date), y: .value(unit.symbol, unit.value(point.temperature)))
          .foregroundStyle(.blue.opacity(0.1))
        LineMark(x: .value(L10n.t("Thời gian"), point.date), y: .value(unit.symbol, unit.value(point.temperature)))
          .foregroundStyle(.blue).lineStyle(StrokeStyle(lineWidth: 1.5))
      }.chartYScale(domain: unit.value(0)...unit.value(130)).chartXAxis(.hidden)
    }
  }
}
