# Configurable return-to-automatic temperature

Settings → General → Return-to-automatic threshold accepts **60–150°C**, default **90°C**. The stepper shows the selected display unit (140–302°F); storage and helper requests use Celsius. Save with Apply threshold. Changes are serialized with other control operations.

This is an app policy for handing control back to macOS, not an Apple-specified safe operating temperature. Raising it delays that hand-back. Sensor curve start/full thresholds retain their independent 20–90°C range.

The root helper validates the range independently, uses fresh telemetry at manual admission and every control tick, and restores all owned fans when any temperature reaches or exceeds the chosen limit. Changing the setting checks active policies immediately. Sensor loss, invalid telemetry, read/write failures and lease expiry remain independent restoration conditions. Failed restores stay owned and are retried; a failed setting update preserves the app preference. Automatic mode remains managed by macOS.

The preference survives app restarts and accompanies single/group preset and scheduled activation. Helper protocol 13 requires the current helper rather than silently accepting the old hard-coded policy. Backups currently contain presets/schedules, not general preferences.

Temperature discovery and sensor-policy resolution retain finite positive readings below 200°C, including 130–150°C. In particular, a hot channel must not disappear at the old 130°C filter while a cool channel continues authorizing control.

## Verification

Journeys were derived from the requested setting and 60–150°C range.

- RED: `./script/test.sh` failed compiling missing threshold APIs, captured in `/tmp/mfc-thermal-red.log`; checkpoint `b06975d`.
- Additional regression RED: a 150°C channel was discarded beside a 50°C channel; `/tmp/mfc-thermal-boundary-red.log`.
- GREEN: `./script/test.sh` passes 98 core and 53 app tests. Tests cover default/custom admission, equality boundary on polling, immediate lowering, highest-channel enforcement, expired lease, invalid settings, persistence, propagation to single/group activation, busy/rejected updates, and corrupt preference fallback.
- `python3 script/check_localization.py`: 346 matching VI/EN keys and format placeholders.
- Tests use fake hardware. No high-temperature physical trial or measured thermal safety claim. Interactive UI rendering has not been visually verified in this session.
