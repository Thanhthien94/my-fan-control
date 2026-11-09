// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "MyFanControl", defaultLocalization: "en", platforms: [.macOS(.v14)],
  products: [
    .executable(name: "MyFanControl", targets: ["MyFanControl"]),
    .executable(name: "fanctl", targets: ["FanControlCLI"]),
  ],
  targets: [
    .target(
      name: "CSMC", linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("CoreFoundation")]),
    .target(name: "FanCore", dependencies: ["CSMC"], resources: [.process("Resources")]),
    .executableTarget(name: "MyFanControl", dependencies: ["FanCore"]),
    .executableTarget(name: "FanControlCLI", dependencies: ["FanCore", "CSMC"]),
    .testTarget(name: "FanCoreTests", dependencies: ["FanCore"]),
    .testTarget(name: "AppSchedulingTests", dependencies: ["MyFanControl", "FanCore"]),
  ], swiftLanguageModes: [.v5]
)
