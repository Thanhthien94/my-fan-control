# Apple Silicon compatibility

This matrix describes preview `0.2.1-preview.1`. Capability handling and injected tests do not certify untested hardware.

| Mac family | Monitoring and fan topology | Control path | Evidence |
| --- | --- | --- | --- |
| M1 / Pro / Max / Ultra | Generation-scoped CPU/GPU and M1 memory mappings; SMC-reported count and bounds | Detect lowercase/uppercase mode keys and optional Ftst at runtime | Injected telemetry/control tests; no physical machine verified |
| M2 / Pro / Max / Ultra | Generation-scoped CPU/GPU mappings; SMC-reported count and bounds | Same capability detection; no model-specific RPM constants | Injected tests; no physical machine verified |
| M3 / Pro / Max / Ultra | Generation-scoped CPU/GPU mappings; SMC-reported count and bounds | Same capability detection | Injected tests; no physical machine verified |
| M4 / Pro / Max | Generation-scoped CPU/GPU/memory mappings | Ftst handoff when exposed; direct mode otherwise | M4 Pro control/restoration measured in 0.2.0; candidate read-only report verified on M4 Pro |
| M5 family | Exact community CPU/GPU keys; unfamiliar keys remain unidentified | Gate-less lowercase/uppercase mode paths; automatic mode must be read back | Injected tests and credited community reference; no physical M5 verified |
| Macs with passive cooling | A readable FNum of zero displays a monitoring-only explanation | Controls remain disabled | Zero-fan injected test; missing FNum is separately marked unavailable |
| Unknown future chips | Common known sensors and raw unidentified channels; no guessed generation mapping | Capabilities detected from readable keys; unsupported writes fail | Parser regression tests prevent M10 from being treated as M1 |

Chip names are not an authorization to write. AppleSMC is undocumented and runtime capabilities can change with macOS/firmware. Pro/Max/Ultra suffixes do not imply a fan count, a fixed RPM range or universal physical left/right positions. The app normally labels fans by SMC index. Mac16,7 retains its previous left/right display aliases; those aliases do not change SMC IDs or certify physical placement. A malformed count or invalid bounds disables all fan controls while preserving readable temperatures. Existing presets are retained; out-of-range presets must be edited for the current Mac.

Control detects lowercase `F<id>md`, uppercase `F<id>Md`, and a validated legacy force mask. Ftst is optional. Missing mode/mask/target keys are detected before taking the global gate. Gate-less automatic-mode writes require bounded readback; failure retains cleanup ownership. The helper protocol is advanced to ensure an older running helper is not silently reused. Readability of a key does not prove it is writable. Delayed firmware responses or grouped operations can exceed the client reply deadline and trigger best-effort restoration; control compatibility remains provisional on untested machines.

## Read-only community report

From an installed 0.2.1 preview:

```sh
/Applications/MyFanControl.app/Contents/MacOS/fanctl compatibility
```

The JSON reports chip, model identifier, fan count/status, reported RPM bounds, mode-key availability, optional handoff gate and sensor counts. It does not request administrator access, write SMC keys or include serial numbers/user names. It does not send data anywhere. Review it before sharing it in a GitHub issue. Version 0.2.0 does not include this new command.

For physical verification, record the model/macOS version, normal automatic readings, a requested RPM inside that fan’s bounds, measured RPM after settling, and return-to-automatic readings. Only test control deliberately through the app and keep macOS protection enabled. Quit competing fan-control utilities. Do not interpret a successful target write as proof that the physical fan changed speed. Sleep/wake, faults and thermal stress need separate testing.

Mappings and control compatibility are based on the credited MIT Stats revision in THIRD_PARTY_NOTICES.md. No proprietary code or license modification is used.
