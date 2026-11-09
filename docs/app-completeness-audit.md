# App and release completeness audit — 0.3.0 preview candidate

Engineering assessment: 80/100, suitable for a clearly marked preview with caveats. This is not legal certification or a claim of stable hardware support.

## Missing release basics repaired

| Surface | Previous gap | Result |
| --- | --- | --- |
| About | Standard panel with incomplete preview/build identity and opaque credits | Native window with full release label, increasing build number, source revision, build date, copyright, requirements and preview status |
| Legal and privacy | Bundled files not discoverable inside the app | Offline MIT/third-party/privacy sheets; Vietnamese privacy copy; permission/independence explanation |
| Help and updates | No usable support/update path in menus | Help menu, guide/compatibility/issue links, user-initiated GitHub update checks with safe release URLs and stable/preview filtering |
| Diagnostics | CLI-only collection | Local export from Settings, no automatic upload, no serial/account/configuration data |
| Configuration | No user-facing backup/recovery | Validated versioned JSON, bounded file size/counts, preview before import, preserve existing data and disable imported schedules |
| Everyday macOS use | Settings had only language/unit, menu only readout | General/Data/Support tabs, optional login item, configurable menu bar sensor/RPM and preset actions |
| Temperature/history | Fahrenheit inconsistent across surfaces | Shared conversion, 10/30/60-minute view and CSV export; curve thresholds stay Celsius |
| Schedules | Disable did not cancel current run; editing could silently replace embedded preset data | Async disable/cancellation with pending-restoration state; explicit saved snapshot choice and unambiguous weekday labels |
| Shutdown/control | Quit could conceal failed restoration; grouped retries lacked one shared deadline | Failed shutdown keeps app open; 25-second write budget shared by a request; cleanup can run after expiry and client allows its completion |
| Input integrity | Persisted/imported malformed sensor thresholds could reach integer formatting | Definition validation before save/import/load; original invalid preferences retained separately for recovery |

## Validation

82 Swift Testing tests passed, including backup merge/idempotency, malformed data, safe update destinations/channels, semantic preview ordering, metadata, schedule disable/snapshot identity and shared operation budgets. VI/EN has 304 matching keys and format placeholders. Native optimized build and C warning/error checks passed.

Observed on M4 Pro: About in VI/dark and EN/light; version/build/revision/requirements; offline MIT/third-party/Vietnamese privacy sheets; successful live manual GitHub update check; native settings tabs; exported backup containing the existing 2000/2950 RPM presets; saved diagnostics with visible success. Save-panel automation briefly timed out once; the file was valid and the app main thread was idle, and a later native diagnostics save returned normally. No app hang was inferred from the automation timeout.

## Still required before a stable distribution

- Developer ID signing/notarization and a more strongly authenticated/pinned privileged-helper lifecycle. Current same-user socket authentication and ad-hoc preview limits remain documented.
- Physical control/fault/sleep/wake validation across Mac models, older macOS runtimes and the new timeout path. Mock tests do not prove physical restoration.
- Actual login-item registration/approval and cold login on signed distributable builds. This option was left disabled during QA.
- Clean-machine/quarantined installation. Public preview Open Anyway instructions remain necessary.

New core-path line coverage: version comparison 93.3%, configuration backup 97.9%, release catalog 96.2%, display/CSV 85.7%, fan-key controller 84.3%. These are file-level figures, not full GUI coverage.

No existing preset or enabled login-item preference was overwritten during testing. Live snapshots and preference backups stay in ignored local evidence; `.codex` remains excluded.

Final preview fixes: automatic pending/applied status is separate from dirty manual presets; the duplicate automatic/status row was removed. Mac16,7 keeps its previous left/right display aliases without changing SMC control IDs. Regression coverage and native GUI inspection confirm these display fixes.
