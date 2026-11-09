import AppKit

enum AppIdentity {
  /// Read our own bundled artwork; LaunchServices can cache a pre-icon development bundle.
  static let icon: NSImage = {
    guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
      let image = NSImage(contentsOf: url)
    else { return NSImage(named: NSImage.applicationIconName) ?? NSImage() }
    return image
  }()
}
