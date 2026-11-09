# Preset activation upgrade

The 0.1 preview's preset flow was incomplete. Selecting a menu item only copied fields into a form, generated a new policy UUID when applying, appended duplicate presets on save, disabled Apply before authorization, and cleared action errors during telemetry polling. The first physical test also exposed a broken detached helper launch and missing Apple Silicon thermal-controller handoff.

The upgrade provides a visible saved-preset library, stable IDs, update/copy/delete actions, explicit target selection, a fixed visible Apply area, integrated user-initiated macOS authorization, and separate persistent operation/telemetry status. Existing presets and schedule snapshots remain compatible.

The privileged service runs under its authorized launcher while the GUI handshakes asynchronously. It reports a protocol version, active policies separately from pending restoration, and startup failures. Legacy service retirement verifies the endpoint peer, executable identity and system-owned fan state before stopping that service; stale sockets are removed only after bounded ownership/inode/connection checks.

For Apple Silicon machines exposing `Ftst`, a manual request takes the thermal-controller handoff gate before issuing the bounded mode/target pair. When the gate is released, mode 1 can be used by thermalmonitord itself and is not reported as a user-forced fan. The final owned fan returns the gate to macOS; failure and lease cleanup use the same path. Compatibility behavior is based on the credited MIT Stats implementation, with bounded retries and explicit readback.

45 automated tests cover saved-preset persistence/identity/update, permission cancellation/failure, protocol migration, operation-error retention, per-fan/group policies, handoff sequencing and cleanup, schedules and injected failures. Live M4 Pro verification is still required for the latest handoff change; automated tests do not establish physical control.
