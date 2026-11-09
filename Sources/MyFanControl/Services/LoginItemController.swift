import FanCore
import Observation
import ServiceManagement

@MainActor @Observable final class LoginItemController {
  var enabled = SMAppService.mainApp.status == .enabled
  var requiresApproval = SMAppService.mainApp.status == .requiresApproval
  var error: String?
  func refresh() {
    enabled = SMAppService.mainApp.status == .enabled
    requiresApproval = SMAppService.mainApp.status == .requiresApproval
  }
  func setEnabled(_ value: Bool) {
    do {
      if value { try SMAppService.mainApp.register() }
      else { try SMAppService.mainApp.unregister() }
      error = nil
    } catch { self.error = error.localizedDescription }
    refresh()
  }
  func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
