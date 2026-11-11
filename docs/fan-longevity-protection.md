# Fan Longevity Protection — hardware-floor policy

In **Settings → General → Fan Longevity Protection** / **Cài đặt → Chung → Bảo vệ tuổi thọ quạt**, the default-on setting now combines a keep-spinning hardware floor with bounded upward target changes. This replaces the former attempt to command a 0→200→1000 startup sequence, following the user's explicit choice and measured firmware startup limits.

Manual policies now always use each fan's reported hardware floor and ceiling. The app-wide custom minimum setting and helper override have been removed. Fixed preset values below the hardware floor are clamped when applied; sensor curves interpolate from that floor to the fan's maximum. Existing schedules use the same helper policy. Saved preset definitions are retained.

The first protected target starts at the effective floor, or the fan's current running RPM if higher, capped at the requested goal. Further increases run at up to **500 RPM/s** using independent monotonic per-fan state. They stop at the policy's requested target and cannot exceed the validated hardware maximum. Repeated requests do not accelerate the ramp; elapsed credit is capped at two seconds. Reductions and automatic-restoration requests are not delayed by this ramp. A command never ramps below the effective floor.

Turning protection off sends normal hardware-bounded targets directly; it does not enable zero/low overrides. Toggling protection live recalculates active targets immediately; a failed update restores owned fans and retains the prior preference. Slider, curve labels and preset matching use hardware bounds. The removed global `minimumRPM` preference is deleted on launch.

Automatic mode is managed by macOS and can still stop fans. Thermal/data/lease restoration always takes priority over keep-spinning behavior. The first firmware-controlled start can still produce a kick: keeping fans spinning reduces subsequent stop/start cycles but is not a guarantee of physical acceleration or longer life. See the [measured earlier behavior](startup-measurement-2026-11-11.md). No long-term lifetime measurements are available.

Helper protocol **12** requires the existing safe helper upgrade flow. The same app-wide preference is carried by manual single/group requests and scheduled applies. The driver retains bounded gate acknowledgement, mode/target readback, rollback and retry ownership.

## Verification — 2026-11-11

The final feature uses hardware floors only. The user's global-override removal request supersedes earlier zero/custom-floor behavior.

RED `386227a`: migration tests ran and failed because old minimum preferences still affected bounds and remained stored. GREEN `33d0330`: `./script/test.sh` passed **143 tests** (93 core, 50 app). Obsolete custom-override tests were retired, with hardware-floor/slew/safety tests retained and migration/preset-preservation coverage added. `python3 script/check_localization.py` passed **340 matching VI/EN keys/placeholders**. Optimized native build and strict signature checks passed. No coverage percentage is claimed.

Source `33d0330` was installed in Applications after normal quit. Native UI confirmed no minimum-RPM setting in General, protection still enabled, and the fixed-RPM slider still bounded at 1350–5777 RPM on the tested Mac. The legacy global preference was cleared and existing presets retained. No new physical control trial was performed for this removal; the earlier firmware trace concerns a superseded zero-start implementation.

Self-review: accuracy 4/5 (tests/UI verified; physical slew not remeasured), completeness 4/5 (UI, persistence and helper override removed; other-model firmware behavior remains unverified), clarity 4/5 (hardware bounds apply with protection either on or off), actionability 5/5 (candidate installed), conciseness 4/5 (removed the dead override path). Overall 4.2/5.
