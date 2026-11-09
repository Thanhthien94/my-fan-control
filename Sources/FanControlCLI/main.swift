import Darwin
import FanCore
import Foundation

do {
  let args = Array(CommandLine.arguments.dropFirst())
  if args.isEmpty || args == ["snapshot"] {
    let snapshot = try SMC().snapshot()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    print(String(decoding: try encoder.encode(snapshot), as: UTF8.self))
  } else if args.count == 3, args[0] == "serve", args[1] == "--uid", let uid = UInt32(args[2]),
    uid > 0
  {
    // Launching as root is explicit; this CLI never elevates itself.
    try HelperServer(uid: uid).run()
  } else {
    throw FanError.invalid(L10n.t("Dùng: fanctl snapshot | sudo fanctl serve --uid <user-id>"))
  }
} catch {
  fputs("\(error.localizedDescription)\n", stderr)
  exit(1)
}
