# What each sensor measures

SMC keys are case-sensitive and model-dependent. My Fan Control uses exact key mappings scoped to the chip generation. The component column and detail panel explain the selected reading in VI/EN. Unidentified readings are hidden by default; **Show unidentified SMC keys** reveals them with their raw keys.

| Component | Meaning | Example keys on the tested M4 Pro |
| --- | --- | --- |
| CPU efficiency | Lower-power CPU processing regions | `Te05`, `Te0S` |
| CPU performance | CPU processing regions used for demanding workloads | `Tp01`, `Tp05`, `Tp09`, `Tp0D`, `Tp0b`, `Tp0e` |
| GPU | Regions of the graphics processor; indices are sensors, not GPU core counts | `Tg1U`, `Tg1k`, `Tg0K`, `Tg0L`, `Tg0d`, `Tg0e`, `Tg0j`, `Tg0k` |
| Battery | Temperature at locations in the battery assembly | `TB1T`, `TB2T` |
| SSD / NAND | Region of NAND storage, not SSD health/lifetime | `TH0x` |
| Wi-Fi | Near the Wi-Fi/AirPort module, not signal strength | `TW0P` |
| Airflow | Temperature near the cooling airflow path, not air velocity | `TaLP`, `TaRF` |
| Memory proximity | Near unified-memory components; no matching key was observed in the recorded M4 Pro snapshot | `Tm0p`, `Tm1p`, `Tm2p` are cataloged for M4-generation machines |

The CPU sensor numbers are labels from the community catalog and do not identify a macOS scheduler core. A chip can expose more thermal channels than published mappings cover. The tested M4 Pro also exposes keys such as `TCMz`, `TVXh`, `Tp23`, `Ts0P` and `TB0T` without an established mapping in the selected reference; the app deliberately does not assign them a component.

An important collision: `Tp0P` is listed as a power-board sensor on Intel and a CPU performance sensor on M1. It is left unidentified on M4. Similarly, `Tm0P` (uppercase P) and `Tm0p` (lowercase p) have different catalog meanings. Mapping an entire prefix across all Macs would mislabel these readings.

The highest value in the overview/chart is the maximum of all currently readable temperature channels, including unidentified channels. It is not labeled “CPU temperature.” The control helper's thermal guard also considers all readable channels; filtering the table does not disable that guard.

## Sources and confidence

Mapping facts are adapted from the open-source [Stats sensor catalog](https://github.com/exelban/stats/blob/1a4a9a6079196cf1ba87124eca2b6ba4e674024a/Modules/Sensors/values.swift#L493), revision `1a4a9a6079196cf1ba87124eca2b6ba4e674024a` (MIT; notice retained in THIRD_PARTY_NOTICES.md). These are community mappings, not Apple hardware specifications. The local snapshot confirms that a key exists and returns a value; it does not physically verify the sensor location.

Exact physical positions, undocumented sensor aliases, and model-specific calibration remain unknown. The app keeps those limits visible instead of inferring a component from a plausible temperature or key prefix.
