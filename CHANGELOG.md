# Changelog

## 0.3.4-preview.1 — 2026-11-19

- Dynamic hottest-sensor selection for manual policies, saved presets and schedules.
- Restore affected fans to automatic before deleting active presets; retain presets on recovery failures.
- Independent per-fan upward ramp from hardware minimum/current RPM, capped at 500 RPM/s. Initial firmware startup kick remains possible; no measured lifetime claim.
- Remove global minimum RPM override; sliders and preset targets respect per-fan hardware bounds.
- Configurable return-to-automatic temperature: 60–150°C, default 90°C, applied immediately and enforced by helper protocol 13. Preserve high-temperature telemetry through the configurable range.
- Validation: 151 tests, 346 matching VI/EN keys, optimized arm64 packaging and strict ad-hoc signature checks. No physical high-temperature or new-ramp validation; other Mac models remain unverified.

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
