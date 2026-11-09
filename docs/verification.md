# Preview verification

This project is an early independent implementation. It is not a verified feature-for-feature replacement for another commercial utility.

## Completed locally

- Native SwiftUI app and `fanctl` compile using Swift 6.4.2, the installed Command Line Tools and macOS 26.5 SDK. The local 27.2 CLT SDK declares an unavailable SwiftUI macro plugin; the scripts select the available stable SDK without modifying global developer settings.
- 13 Swift Testing tests in four suites pass: policy boundaries/invalid inputs, SMC decoding, expired leases, lost telemetry/high temperature, partial write failure, restoration retry, fresh-telemetry validation, preset serialization, VI/EN resolution and generation/case-sensitive sensor mappings.
- Localization validation confirms 154 matching VI/EN keys and matching formatting placeholders.
- Live read-only SMC monitoring was observed on `Mac16,7`, Apple M4 Pro: two fans, minimum 1350 RPM, maximum 5777 RPM, and up to 294 readable temperature channels. Both fans were at 0 RPM in automatic mode during the recorded sample. Channel availability varies over time.
- The `.app` bundle launches with a normal window, menu bar item, real sensor table, RPM/policy controls and temperature chart. UI inspection covered fixed-RPM/sensor forms and sensor-key search. English labels and native Settings were observed.
- The fan icon and fresh-green airflow artwork were visually inspected before native ICNS packaging. Original local brand artwork and raw device evidence are excluded from Git.

## Still unverified

- Administrator authorization and actual hardware fan writes/readback/physical acceleration.
- Real-device recovery after app/helper crashes, sleep/wake, sensor/driver failures, and high-temperature load.
- Physical sensor locations: community mappings identify likely components; key existence does not verify physical placement.
- Other Mac models, Intel hardware and older macOS runtime versions.
- Developer ID signing, notarization and clean-machine download/install.

The distribution is a clearly marked preview with controls inactive until the user authorizes them. Fake-hardware tests prove the policy/session code paths under their test conditions; they do not establish fan-write compatibility or thermal safety on a physical Mac.
