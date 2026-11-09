# Silicon compatibility test evidence

Journeys were derived from the request to audit and support other Apple Silicon Macs after publishing 0.2.0.

- Users on fanless/unreadable-fan systems retain temperature monitoring with fan controls unavailable.
- Users on differing firmware receive verified automatic restoration rather than a successful-write assumption.
- Users see generation-scoped sensor labels and can collect a read-only compatibility report.

RED: `./script/test.sh` compiled the added telemetry test and failed because `SMCTelemetryReader` did not exist. The reproducer was committed as `b0b0cb7`. Runtime firmware/readback regressions were added in the same test checkpoint.

GREEN: `./script/test.sh` passed after telemetry separation, capability validation, mode/mask readback and catalog updates (`aca2c56`). Subsequent coverage tests additionally exercised delayed automatic mode, mask preservation and malformed masks.

| Guarantee | Test file | Type |
| --- | --- | --- |
| Zero reported fans differ from unavailable fan count | SMCTelemetryTests.swift | Injected SMC telemetry |
| Invalid count/bounds disable controls but retain temperatures | SMCTelemetryTests.swift | Injected SMC telemetry |
| 1/2/4 fans retain each fan’s reported limits | SMCTelemetryTests.swift | Injected SMC telemetry |
| Gate-less firmware must confirm automatic mode; delayed confirmation is accepted | SiliconCompatibilityTests.swift | Injected firmware |
| Missing control keys cause no gate writes | SiliconCompatibilityTests.swift | Injected firmware |
| Legacy mask verification preserves other fans’ bits | SiliconCompatibilityTests.swift | Injected firmware |
| Unknown generations do not inherit M1 keys; M1 memory and M5 keys are scoped | SiliconCompatibilityTests.swift | Unit |

Coverage command: source `script/toolchain.sh`, then run `swift test --disable-xctest --enable-swift-testing --enable-code-coverage` with the script’s SDK and CLT Testing plugin arguments. Measured line coverage for changed core paths: FanKeyController 83.7%, SMCTelemetryReader 90.9%, SensorCatalog 86.7%. These are file-level numbers, not an app-wide coverage claim. The run passed 45 core and 15 app tests (60 total; parameterized tests include several inputs).

An optimized candidate build succeeded. Its read-only compatibility report on Mac16,7 / M4 Pro found two fans, uppercase mode keys, Ftst, and min/max 1350/5777. No candidate physical writes, fanless UI on real hardware, M1/M2/M3/M5 devices, sleep/wake or thermal stress have been verified. No claim of physical support for every model follows from the injected tests. The installed public app remains 0.2.0.

A second runtime RED checkpoint, `6bf4f6a`, demonstrated a retained legacy force bit after global gate handback (`globalHandbackAlsoClearsTheLegacyMask`). Clearing and verifying the owned bits before releasing Ftst made the same test GREEN; unowned bits are preserved.
