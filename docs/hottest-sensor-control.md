# Dynamic hottest-sensor curves

In Sensor mode, choose **Hottest sensor (automatic selection)** / **Cảm biến nóng nhất (tự chọn)** at the top of the sensor picker. Set the curve thresholds, then save/apply as usual. Selecting the source only edits the draft. The editor shows the winning sensor/key and temperature from each latest app sample, respecting the display temperature unit; curve thresholds remain Celsius.

All readable, valid channels participate, including unidentified SMC keys. Valid telemetry is finite and strictly between 0 and 130°C, matching the telemetry reader. Equal temperatures use key order for a stable display. The source is selected again from every fresh sample (normally 1 Hz), so a CPU/GPU or other channel can replace the previous winner. The helper independently rereads hardware; it never uses cached GUI telemetry to authorize fan writes. App and helper samples are independent and need not have identical timestamps. Opening the menu-bar snapshot does not pause monitoring or curve control.

The choice persists as the reserved selector `auto:hottest` in the existing preset sensor field, distinct from four-byte SMC keys. Presets, embedded schedule policies and configuration backups retain the selector rather than saving the current winning sensor. Existing explicit sensor selections remain pinned. An older app rejects this new selector during definition validation; do not downgrade expecting these new presets to work. The helper protocol is now 7, so the existing authorization flow retires an older helper before applying the new policy.

Single-fan and all-fan policies share resolution and retain each fan's own RPM bounds. If a previous winner disappears, remaining fresh valid readings can take over. Missing data, a failed read/write, expired lease or any discovered temperature at/above 90°C still causes automatic restoration under the existing safety rules. The new source does not bypass those rules.

## Verification — 2026-11-11

User journeys were derived from the request: select a dynamic source, keep sampling, save/reuse it, and retain existing explicit-source behavior and safety recovery.

RED checkpoint `0e9efe8`: `./script/test.sh` compiled and ran the new tests. Hottest-session tests failed with missing sensor data; definition/backup/schedule tests failed because the reserved selector was unsupported. App activation/save assertions also failed. Existing explicit-source tests passed.

GREEN checkpoint `8d5039e`: the same command passed **111 tests** (75 core, 36 app), including ten new tests. `python3 script/check_localization.py` passed **328 matching VI/EN keys/placeholders**. `MFC_CONFIGURATION=release ./script/build_and_run.sh --build-only` built the native app and helper; `codesign --verify --deep --strict` passed. CLT emitted existing missing optional search-path/arclite warnings, with no build failure.

| Guarantee | Test | Kind | Result |
|---|---|---|---|
| New sample can switch CPU/GPU/unknown winner and target RPM | HottestSensorTests.eachHelperSampleCanSwitchToANewHottestSensor | Fake hardware | PASS |
| Both fans retain independent RPM bounds | HottestSensorTests.groupUsesHottestSampleWithEachFansOwnLimits | Fake hardware | PASS |
| Remaining sensor replaces a disappeared winner | HottestSensorTests.disappearanceOfPreviousWinnerSelectsRemainingFreshSensor | Fake hardware | PASS |
| Missing/invalid/hot samples and lease expiry restore both fans | HottestSensorTests.missingInvalidHotOrExpiredSamplesRestoreBothFans | Fake hardware | PASS |
| Explicit keys stay pinned and restore on loss | HottestSensorTests.legacyExplicitSensorStaysPinnedAndStillRestoresOnItsLoss | Fake hardware | PASS |
| Finite/range validation and deterministic ties | HottestSensorTests.resolverRejectsInvalidReadingsAndBreaksTiesStably | Unit | PASS |
| Unsupported selectors remain invalid | HottestSensorTests.arbitrarySelectorsAndEmptySelectionRemainInvalid | Unit | PASS |
| Preset/schedule/backup round trip retains dynamic selection | HottestSensorTests.selectionSurvivesPresetScheduleAndBackupRoundTrip | Integration | PASS |
| Save/relaunch and single/all activation, readable summaries | HottestPresetWorkflowTests.savesRelaunchesAndActivatesForOneOrAllFans | App with fake backend | PASS |
| Scheduled policy starts and returns to automatic | HottestPresetWorkflowTests.scheduledHottestPresetStartsAndReturnsToAutomatic | App with fake backend | PASS |

Local UI: installed candidate 0.3.4-preview.1, source `8d5039e`, after normal quit of the previous app. Verified the new picker item, selecting it, live sensor/key/temperature guidance and unsaved-draft state. Existing presets were preserved. No new hottest-source physical fan-control test or administrator authorization was performed. Coverage instrumentation was not run; the counts above are test results, not a coverage percentage or cross-device claim.

Self-review with agent-self-evaluation: accuracy 4/5 (logic tested; physical actuation not tested), completeness 4/5 (requested behavior implemented; additional Mac hardware untested), clarity 4/5 (VI/EN source and latest winner shown; unidentified channels have no component attribution), actionability 5/5 (candidate installed and selection available), conciseness 4/5 (one shared resolver; documentation includes explicit evidence). Overall 4.2/5. Next useful validation is deliberate physical curve application on a safe-temperature machine; it is not claimed here. The user should be able to find and try the option directly.
