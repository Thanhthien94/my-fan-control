# Fan Longevity Protection

**Settings → General → Fan Longevity Protection** / **Cài đặt → Chung → Bảo vệ tuổi thọ quạt** exposes low-speed startup smoothing as a separate app-wide feature. It is enabled by default and its toggle persists across relaunch. The custom minimum-RPM setting remains independent.

When enabled, a fan starting below 1000 RPM toward a higher target receives an initial rise of at most 200 RPM, capped at 1000. Subsequent commands rise at up to 200 RPM/s below 1000 and 500 RPM/s afterwards. Monotonic elapsed time, per-fan state and a two-second catch-up cap prevent repeated requests from accelerating the ramp. The post-1000 ramp is retained to avoid a jump directly from 1000 to a high final target. See [global minimum RPM](global-minimum-rpm.md).

When disabled, manual policies send their normal validated targets directly. This does not disable thermal, data-loss, lease, bounds or automatic-restoration protection. Enabling/disabling clears stale ramp state; the next helper cycle uses the chosen behavior. Manual single/group requests, including scheduled policies, carry the app preference. Automatic restoration does not change the preference. Helper protocol 10 and its bounded `setFanProtection` command carry the live toggle; no new service or permission is introduced. A failed helper update preserves the previous saved preference and reports an error. Changing the toggle does not start administrator authorization.

The feature name describes its intent. The measured behavior is command smoothing; there are no long-term lifetime measurements, guaranteed physical acceleration/stop results or universal-firmware claims. The Settings description states this explicitly in VI/EN. The feature currently affects app-owned manual policies and schedules, not macOS automatic fan behavior.

## Verification — 2026-11-11

User journeys: find the named feature, toggle it independently of the RPM floor, retain the choice after relaunch, and keep thermal protection active when smoothing is off.

RED `bc844fe`: `./script/test.sh` compilation failed because ControlSession had no protection toggle or state. GREEN `5530226`: the same command passed **139 tests** (89 core, 50 app), including five new feature tests. `python3 script/check_localization.py` passed **345 matching VI/EN keys/placeholders**. Optimized native build, script-based launch and strict signature verification passed. No coverage percentage is claimed.

Tests cover default-on, off/direct command, reenabled fresh ramp, heat restoration with smoothing disabled, setting persistence, single/group transport, rejected helper updates and busy-state rejection. Existing startup-rate and minimum-RPM tests remain passing.

Native UI: candidate source `5530226` showed the Vietnamese checkbox enabled by default. Toggled off and on with matching confirmations, leaving it enabled. Dashboard showed **0 RPM** as the slider lower bound, resolving the previous post-save AX observation gap. The candidate was installed in Applications after normal quit and reopened successfully; existing presets and custom minimum 0 were retained. Hardware control remained inactive during this QA. No new physical fan-control or longevity measurement was performed.

Self-review: accuracy 4/5 (command behavior and UI verified; lifetime unmeasured), completeness 4/5 (toggle/default/persistence/thermal independence covered; firmware response untested), clarity 4/5 (feature name paired with explicit mechanism and measurement limit), actionability 5/5 (candidate installed, default enabled), conciseness 4/5 (one setting shared through helper). Overall 4.2/5. Physical startup verification remains the next useful validation, without inferring lifetime benefit from it.

The [shared-gate startup fix](startup-handoff-fix.md) retains initial group RPM baselines, starts ramp timing after write confirmation and replaces the fixed gate sleep with bounded readback. Physical firmware kick behavior still requires measurement.

Follow-up real-device measurement reproduced a startup peak despite these software changes. See [measured command versus physical RPM](startup-measurement-2026-11-11.md); the ramp must not be presented as preventing the firmware-controlled initial rise.
