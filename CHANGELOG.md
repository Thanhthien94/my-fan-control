# Changelog

## 0.3.3-preview.1 — 2026-11-10

- Keep native menu highlights stable by holding menu readings and status-label width while the menu is open, including preset submenus.
- Explain in VI/EN that menu readings reflect the time of opening. Background monitoring and safety checks continue.
- Verified with 101 tests, localization checks and user hover confirmation on the tested M4 Pro.

## 0.1.0-preview.1 — 2026-11-09

- Native SwiftUI dashboard, menu bar summary and real AppleSMC fan/temperature monitoring.
- Per-fan and shared all-fan automatic, fixed-RPM and temperature-curve policies, local named presets, and a bounded privileged helper.
- Vietnamese and English, with a live language selector.
- Chip-scoped sensor/component labels, explanations, references and explicit unidentified readings.
- SkyTruong-palette fan icon with green airflow, native ICNS packaging and explicit Dock icon loading.
- Countdown, specific-date and weekly schedules; per-fan ownership, conflict checks, cancellation, activity history and automatic restoration requests.
- MIT licensing, contribution/branch workflow, protected main/develop branches and macOS CI.

Preview limitations: hardware writes, administrator authorization, physical recovery, thermal stress, other Mac models and clean-machine installation are not validated. The app is ad-hoc signed, not Developer ID signed/notarized. See docs/verification.md and docs/security.md.
