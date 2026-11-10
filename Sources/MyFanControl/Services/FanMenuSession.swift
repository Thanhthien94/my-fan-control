import AppKit
import FanCore
import Observation
import OSLog

/// Small AppKit lifecycle bridge; SwiftUI still owns the menu and all its actions.
@MainActor @Observable final class FanMenuSession: NSObject {
  private(set) var frozen: FanMenuPresentation?
  @ObservationIgnored private weak var store: FanStore?
  @ObservationIgnored private var tracking = Set<ObjectIdentifier>()
  private let center: NotificationCenter
  private let logger = Logger(subsystem: "vn.thiendev.myfancontrol", category: "MenuTracking")

  init(center: NotificationCenter = .default) {
    self.center = center
    super.init()
    center.addObserver(self, selector: #selector(began(_:)), name: NSMenu.didBeginTrackingNotification, object: nil)
    center.addObserver(self, selector: #selector(ended(_:)), name: NSMenu.didEndTrackingNotification, object: nil)
  }
  deinit { center.removeObserver(self) }
  func bind(_ store: FanStore) { self.store = store }
  func presentation(_ store: FanStore) -> FanMenuPresentation { frozen ?? FanMenuPresentation(store) }

  private func belongsToStatusMenu(_ menu: NSMenu) -> Bool {
    var candidate: NSMenu? = menu
    while let current = candidate {
      if current.items.contains(where: {
        $0.title == L10n.t("Mở bảng điều khiển") || $0.attributedTitle?.string == L10n.t("Mở bảng điều khiển")
      }) { return true }
      candidate = current.supermenu
    }
    return false
  }
  @objc private func began(_ notification: Notification) {
    guard let menu = notification.object as? NSMenu else { return }
    let matches = belongsToStatusMenu(menu)
    logger.debug("menu_tracking_begin_observed status_menu=\(matches, privacy: .public)")
    guard matches, let store else { return }
    if tracking.isEmpty {
      frozen = FanMenuPresentation(store)
      logger.info("status_menu_tracking_begin")
    }
    tracking.insert(ObjectIdentifier(menu))
  }
  @objc private func ended(_ notification: Notification) {
    guard let menu = notification.object as? NSMenu,
      tracking.remove(ObjectIdentifier(menu)) != nil else { return }
    if tracking.isEmpty {
      frozen = nil
      logger.info("status_menu_tracking_end")
    }
  }
}
