# Mode feedback and monitoring improvements — 0.3.1 preview candidate

The live mode overview is unchanged. The editor explicitly describes a configuration to apply. Its action distinguishes authorization, applying, restoration, invalid configuration, pending saved/manual/automatic drafts and confirmed application. Already-applied configurations have a disabled Applied action; selecting another configuration does not silently change hardware.

Automatic success reports automatic control, regardless of the manual preset name retained in the draft. Manual receipts state the actual mode, target/sensor and fan scope. A receipt is cleared when the confirmed state no longer matches, even without a helper notice, and expires after six seconds. Warnings and success receipts do not appear together. Runtime RED tests reproduced both the wrong automatic-success name and stale manual success before the fixes.

The sensor picker uses generation-scoped identified CPU/GPU/component groups first, with stable natural ordering independent of temperature changes. Unknown readings are opt-in; the explicitly selected unknown reading remains visible. Missing selections retain their key with an unavailable label. Unknown labels include the raw key once. Existing selected sensor IDs are not changed.

Monitoring targets one-second cadence, including read time. Slow reads do not queue missed polls. History retains up to 3600 samples from the most recent hour, excluding future samples after backwards clock changes.

Validation: 93 automated tests (62 core and 31 app); 316 matching VI/EN keys/placeholders; native optimized build. Tests cover component priority, selected-unknown preservation, stable ordering, CSV/key display, hour retention, wrong automatic receipt, silent handback, receipt expiry, failed automatic requests and editor pending/progress/invalid states. These are UI/state changes, not a new physical hardware control certification.
