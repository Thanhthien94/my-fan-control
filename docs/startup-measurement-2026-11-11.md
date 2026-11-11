# Measured startup behavior on Mac16,7 — 2026-11-11

A real-device measurement reproduced the user's report on candidate source `1949a1a`, helper protocol 10, protection enabled and custom minimum 0. The selected fixed preset was 3150 RPM for both fans. The code-level handoff fixes did **not** prevent the measured startup peak.

| Relative time | Gate / modes L,R | Targets L,R (RPM) | Measured L,R (RPM) |
|---|---|---|---|
| 23.176 s | 1 / 3,3 | 0 / 0 | 0 / 0 |
| 26.325 s | 1 / 0,0 | 1350 / 1458 | 0 / 0 |
| 31.044 s | 1 / 1,1 | 200 / 200 | 1240 / 1360 |
| 31.258 s | 1 / 1,1 | 200 / 227 | 1363 / 1552 |
| 31.362 s | 1 / 1,1 | 287 / 227 | 1569 / 1509 |

The reported targets rose to 1350/1458 before forced mode 1 was accepted. Once manual mode was active, low command targets did not imply matching physical speeds: measured RPM initially exceeded 1500. This supports a firmware/handoff starting-speed constraint in the tested sequence. It does not prove that every possible SMC write sequence must have the same behavior, nor establish a universal limit for other Macs.

Method: a temporary **read-only** C probe linked the repository's CSMC reader and sampled `Ftst`, `F0Md/F1Md`, `F0Ac/F1Ac` and `F0Tg/F1Tg`. There were 1200 rows at a median 0.105351-second interval (~9.49 samples/s). Reads within each row were sequential, not atomic; SMC's physical telemetry update frequency is unknown. Values shown are observed samples, not guaranteed absolute physical peaks. The [sanitized summary](startup-measurement-2026-11-11.json) contains the exact rows and environment identity. Raw CSV and the temporary probe are retained locally under /tmp, not published as private runtime dumps.

Two GUI instances were found during setup: `dist` owned helper/control, while Applications was monitoring. The monitoring instance was closed, and the trial used the actual controlling instance. Its preset was returned to automatic, both measured fans reached 0, then the existing 3150-RPM preset was applied to both through native UI. At completion the original 3150-RPM policy was active again, with both fans around the target. Saved preset definitions were not changed, no new authorization was requested, and both read-only probes finished.

No claim is made that the soft command ramp physically prevents this kick or extends fan lifetime. Possible product responses are to retain explicit zero requests with an honest handoff limitation, or to offer a separate keep-spinning floor under protection to reduce later stop/start cycles. Keeping fans spinning still cannot promise to eliminate the first firmware-controlled start. The user's preferred behavior is pending; no new RPM floor or policy semantics were applied during this measurement turn.
