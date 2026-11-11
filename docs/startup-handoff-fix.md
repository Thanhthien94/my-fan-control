# Historical zero-start protection and the shared SMC gate

This report documents the superseded zero-start implementation. The current [hardware-floor protection policy](fan-longevity-protection.md) replaces its 200-RPM startup behavior; the gate/readback fixes remain.

The user observed two symptoms: right-fan startup appeared to skip smoothing, and a fan rose above 1000 RPM before settling to 200 and beginning its ramp. The fixes below address demonstrated software causes; they do not prove the absence of a firmware-controlled physical kick.

1. Group configuration captured initial telemetry, then reread each fan before its write. Opening Ftst for the first fan can spin the other fan above 1000 before its turn. The ramp now uses the lower of that fan's initial group RPM and fresh RPM for startup detection. Bounds and thermal safety still use fresh per-fan telemetry. Hardware fan ordering/IDs are unchanged.
2. Ramp state was timed before the blocking handoff. Successful writes now rebase the ramp clock at confirmation, so gate/handshake time does not count as acceleration credit.
3. The driver previously slept a fixed three seconds after opening/reacquiring Ftst, even with immediate gate acknowledgement. It now polls readback only when needed (up to 60 reads, 50 ms apart), retains the manual-operation budget, and writes the low target as soon as the gate acknowledges. Mode/target writes remain sequential and independently verified; no atomic multi-fan write is claimed.
4. A rejected mode write previously skipped that round's target write. The bounded pair loop now attempts the low target even after a transient mode error and only succeeds if both mode and target readback match. Cancellation/budget checks still run before the target write. Target failures and failed restoration retain ownership for cleanup/retry.

Helper protocol **10** forces the existing safe helper upgrade flow rather than silently reusing the old implementation. Thermal/data/lease restoration, per-fan RPM maxima and the independent protection toggle remain in place.

## Verification — 2026-11-11

Journeys came from the user's observations. `./script/test.sh` provided these checkpoints:

| Guarantee | RED | GREEN | Evidence |
|---|---|---|---|
| Shared-gate spinup cannot bypass right-fan startup; handoff time gives no ramp credit | `98d4523` | `7e48db1` | Fake initial 0 RPM on both fans; first write spins right to 1600 and consumes 3 seconds. Both initial targets must be 200; one second later both must be 400. Also covers right-only control and fresh-temperature rejection after the first write. |
| No fixed wait when gate already acknowledges; delayed acknowledgement retries readback | `cddb319` | `32db107` | Before the fix, a normal low-target write waited 3 seconds and delayed readback failed. Updated handoff tests pass without fixed sleep. |
| A temporarily rejected mode cannot starve the low target | `01ed3bc` | `1949a1a` | Fake firmware refuses mode until target is nonzero. Old code failed with F0Md -130; new code stages 200 and confirms the pair after two mode attempts. |

Final suite: **145 tests** (95 core, 50 app). Localization: **345 matching VI/EN keys/placeholders**. Optimized native build and strict ad-hoc signature verification passed. Existing operation-budget, rollback and recovery tests pass. Coverage instrumentation was not run; counts are not a coverage percentage.

Before replacing the app, native UI showed the old build in Automatic with an `AppleSMC F0Md: -130` message. This is an observed symptom, not proof that the fake mode/target dependency exactly models this firmware. Normal quit completed; candidate source `1949a1a` was installed in Applications and reopened successfully. Saved presets were retained, the minimum remained 0, protection remained enabled, and no new fan policy or administrator authorization was issued during this verification. Public release was not performed.

Physical fan acceleration after the fix has not been measured. Firmware may enforce a minimum starting speed or a brief kick even when low command targets are sent immediately. Removing software wait and preserving ramp state must not be described as guaranteeing a physical 0→200→400 trajectory or a lifetime benefit.

Self-review: accuracy 4/5 (all software reproductions pass; physical trace missing), completeness 4/5 (both reported software paths addressed; actual kick still needs measurement), clarity 4/5 (fresh safety readings distinguished from startup detection), actionability 5/5 (candidate installed with forced helper upgrade), conciseness 4/5 (narrow handoff/ramp changes). Overall 4.2/5. Next useful verification is a physical start of both fans, observing target and measured RPM separately.

Follow-up real-device measurement reproduced a startup peak despite these software changes. See [measured command versus physical RPM](startup-measurement-2026-11-11.md); the ramp must not be presented as preventing the firmware-controlled initial rise.
