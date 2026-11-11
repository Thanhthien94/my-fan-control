# App-wide minimum RPM

**Settings → General → App-wide minimum RPM** stores an optional custom minimum, including **0**. With no custom value the app uses each fan's reported hardware minimum. The setting is local to the app, not a preset field or part of preset/schedule backups.

The effective floor also depends on [Fan Longevity Protection](fan-longevity-protection.md):

| Protection | Effective floor |
|---|---|
| On (default) | Higher of the custom minimum and each fan's hardware minimum |
| Off | Custom minimum, including 0; hardware minimum when no custom value is set |

A stored zero is retained when protection is enabled. Settings displays both the stored value and per-fan effective floors. The fixed-RPM slider follows the effective common range for its selected fan scope; sensor curves retain per-fan bounds. Selecting/loading a fixed preset clamps its editable display without rewriting its stored definition. Fixed values below the effective floor run at the floor; higher requested values remain bounded by each fan's maximum. Scheduled requests carry both settings.

Protected increases start at the effective floor/current running RPM and rise at up to 500 RPM/s toward the goal. Protection off permits raw zero/low requests, subject to firmware acceptance. Reported target acknowledgement does not establish physical fan stop. The first firmware-controlled kick can still occur; see the [real-device trace](startup-measurement-2026-11-11.md).

Changing a floor or protection live validates all targets before writes. A failed write restores owned fans and does not persist the rejected setting. A saved preset is not silently rewritten. Disabling a custom minimum raises a running zero/low fixed preset to the default hardware minimum. macOS Automatic mode remains unchanged. Current helper protocol is **11**.

Final verification for the floor-based policy is documented in [Fan Longevity Protection](fan-longevity-protection.md): 154 tests, 347 matching VI/EN keys/placeholders, native build/signature checks and UI on/off floor checks. The earlier 0→200 startup implementation was superseded; its physical limitations are retained in the measurement report.
