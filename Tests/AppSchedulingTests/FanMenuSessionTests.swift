import AppKit
import FanCore
import Foundation
import Testing

@testable import MyFanControl

@MainActor struct FanMenuSessionTests {
  private func rootMenu() -> NSMenu {
    let menu = NSMenu(title: "Status")
    menu.addItem(withTitle: L10n.t("Mở bảng điều khiển"), action: nil, keyEquivalent: "")
    return menu
  }
  private func reading(_ temperature: Double) -> Snapshot {
    Snapshot(fans: [Fan(id: 0, name: "Fan", current: temperature * 40, minimum: 1000, maximum: 6000)],
      sensors: [Sensor(id: "test", name: "Sensor", celsius: temperature)])
  }
  @Test func readingsStayStableUntilTheStatusMenuCloses() {
    let (store, _, _, _) = ScheduleExecutionTests().fixture(.now)
    let center = NotificationCenter()
    let session = FanMenuSession(center: center)
    session.bind(store)
    let menu = rootMenu()
    store.snapshot = reading(50)
    center.post(name: NSMenu.didBeginTrackingNotification, object: menu)
    store.snapshot = reading(60)
    #expect(store.hottest?.celsius == 60)
    #expect(session.presentation(store).reading?.sensors.first?.celsius == 50)
    center.post(name: NSMenu.didEndTrackingNotification, object: menu)
    #expect(session.presentation(store).reading?.sensors.first?.celsius == 60)
  }
  @Test func nestedPresetMenuDoesNotUnfreezeTheRootEarly() {
    let (store, _, _, _) = ScheduleExecutionTests().fixture(.now)
    let center = NotificationCenter()
    let session = FanMenuSession(center: center)
    session.bind(store)
    let menu = rootMenu()
    let item = menu.addItem(withTitle: "Presets", action: nil, keyEquivalent: "")
    let child = NSMenu(title: "Presets")
    item.submenu = child
    store.snapshot = reading(50)
    center.post(name: NSMenu.didBeginTrackingNotification, object: menu)
    center.post(name: NSMenu.didBeginTrackingNotification, object: child)
    store.snapshot = reading(60)
    center.post(name: NSMenu.didEndTrackingNotification, object: child)
    #expect(session.presentation(store).reading?.sensors.first?.celsius == 50)
    center.post(name: NSMenu.didEndTrackingNotification, object: menu)
    #expect(session.presentation(store).reading?.sensors.first?.celsius == 60)
  }
  @Test func unrelatedMenusDoNotFreezeTheReadout() {
    let (store, _, _, _) = ScheduleExecutionTests().fixture(.now)
    let center = NotificationCenter()
    let session = FanMenuSession(center: center)
    session.bind(store)
    let menu = NSMenu(title: "Other")
    store.snapshot = reading(50)
    center.post(name: NSMenu.didBeginTrackingNotification, object: menu)
    store.snapshot = reading(60)
    #expect(session.presentation(store).reading?.sensors.first?.celsius == 60)
  }
}
