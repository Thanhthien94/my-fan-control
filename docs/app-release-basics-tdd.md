# Release basics — test evidence

Scope comes from the request to complete the app, with emphasis on About/app information and minimum public-release flows.

RED checkpoints:
- `29135a6`: new version, backup and schedule-disable tests compiled against missing implementations and failed.
- `e847883`: runtime test rejected malformed numeric preview identifiers; `preview.01` was incorrectly accepted before the fix.
- `8e8fbde`: shared write-budget tests failed to compile against the missing injected clock/budget API.
- `095e2ee`: schedule editor lacked a representation for the saved preset snapshot after library changes.
- `117a175`: runtime test showed corrupt original preferences were not retained after a subsequent save.

GREEN: `./script/test.sh` passes 77 tests after the fixes (56 core, 21 app). `python3 script/check_localization.py` passes 304 keys/placeholders. C syntax/warning checks pass with `-Wall -Wextra -Werror`. Native optimized bundle builds and strict signature checks pass.

Coverage run uses the configured CLT SDK and Testing macro plugin with `--enable-code-coverage`. Relevant new core files measured: AppVersion 93.3%, ConfigurationBackup 97.9%, ReleaseCatalog 96.2%, TemperatureUnit 85.7%, FanKeyController 84.3%. UI, login-item approval and physical kernel/firmware behavior are not covered by these percentages.

User-facing guarantees include preserved data/identities during import, all imported schedules disabled, no writes during import, update drafts/untrusted URLs excluded, explicit preview comparison, consistent display units/CSV, schedule disable restoration and snapshot preservation, and bounded manual retries with cleanup still permitted after expiry. See app-completeness-audit.md for live GUI observations and remaining platform limits.
