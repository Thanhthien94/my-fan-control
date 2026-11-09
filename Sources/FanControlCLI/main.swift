import Darwin
import FanCore
import Foundation

do {
  let args = Array(CommandLine.arguments.dropFirst())
  if args.count == 5, args[0] == "retire", args[1] == "--uid", args[3] == "--pid",
    let uid = UInt32(args[2]), let pid = Int32(args[4]), uid > 0, pid > 1, pid != getpid(),
    geteuid() == 0
  {
    // The old endpoint accepts only the GUI user's credential, including during a root repair.
    guard seteuid(uid) == 0 else {
      throw FanError.invalid("Could not verify controller peer identity.")
    }
    let peer = HelperClient.serverPID(uid: uid)
    guard seteuid(0) == 0 else {
      throw FanError.invalid("Could not restore controller repair privileges.")
    }
    guard peer == pid else {
      throw FanError.invalid("Controller process identity changed.")
    }
    let smc = try SMC()
    let query = Process()
    query.executableURL = URL(fileURLWithPath: "/bin/ps")
    query.arguments = ["-p", String(pid), "-o", "comm="]
    let output = Pipe()
    query.standardOutput = output
    try query.run()
    query.waitUntilExit()
    let actual = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let expected = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().path
    guard query.terminationStatus == 0,
      URL(fileURLWithPath: actual).resolvingSymlinksInPath().path == expected
    else { throw FanError.invalid("Legacy controller executable does not match this app.") }
    guard kill(pid, SIGSTOP) == 0 else {
      throw FanError.invalid("Could not pause the previous controller.")
    }
    do {
      try smc.explicitSystemAutomatic()
      guard kill(pid, SIGKILL) == 0 else {
        throw FanError.invalid("Could not retire the previous controller.")
      }
    } catch {
      kill(pid, SIGCONT)
      throw error
    }
    for _ in 0..<40 {
      if kill(pid, 0) != 0 { break }
      usleep(50_000)
    }
    print("Inactive legacy controller retired")
    exit(0)
  }
  if args == ["check"] {
    _ = try SMC().snapshot()
    print("AppleSMC ready")
    exit(0)
  }
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
