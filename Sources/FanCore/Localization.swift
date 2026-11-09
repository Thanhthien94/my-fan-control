import Foundation

public enum L10n {
  // Set only by the single-threaded helper from a validated client request.
  public static var languageOverride: String?
  public static var language: String {
    let choice = languageOverride ?? UserDefaults.standard.string(forKey: "language") ?? "system"
    if choice == "vi" || choice == "en" { return choice }
    return Locale.preferredLanguages.first?.hasPrefix("vi") == true ? "vi" : "en"
  }
  public static func t(_ key: String) -> String {
    text(key, language: language)
  }
  public static func text(_ key: String, language: String) -> String {
    guard
      let path = Bundle.module.path(forResource: language == "vi" ? "vi" : "en", ofType: "lproj"),
      let bundle = Bundle(path: path)
    else { return key }
    return bundle.localizedString(forKey: key, value: key, table: "Localizable")
  }
  public static func f(_ key: String, _ args: CVarArg...) -> String {
    String(format: t(key), locale: Locale(identifier: language), arguments: args)
  }
}
