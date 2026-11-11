# App-wide minimum RPM setting removed

The custom app-wide minimum-RPM setting, its stored override and helper command have been removed at the user's request. The old `minimumRPM` preference is deleted on launch; presets and other preferences are retained. There is no Settings control or helper transport field for it.

Manual fixed targets and sensor curves use each fan's reported hardware floor and ceiling. Legacy fixed values below the hardware floor are clamped when applied, without rewriting saved definitions. Turning off Fan Longevity Protection disables upward slew, not hardware bounds. See [current protection behavior](fan-longevity-protection.md).

Historical measurements of the former zero-start implementation remain in [the real-device report](startup-measurement-2026-11-11.md); they do not describe a current zero override.
