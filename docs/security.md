# Privilege boundary

The GUI is unprivileged. Monitoring uses an IOKit connection to AppleSMC. Fan writes are isolated in the `fanctl serve --uid <uid>` process, started on demand through macOS administrator authorization. No passwords are read or stored by the app.

The root helper binds a Unix socket under root-owned `/var/run`, refuses preexisting paths, applies mode 0600 for the selected UID and checks client credentials with `getpeereid`. The GUI checks that the server's UID is root. Requests are newline-delimited JSON, bounded to 4 KiB, with a one-second server request deadline and a 90-second client reply deadline to accommodate bounded hardware handoff and multi-fan cleanup. Manual writes share a 25-second software budget per request, including a grouped request; each tick starts a fresh budget. Cleanup remains allowed after the write budget expires. An unresponsive IOKit/kernel call cannot be forcibly bounded by this userspace clock. Only `status`, `configure`, `configureGroup`, `setFanProtection`, `automatic` and `shutdown` are accepted. There are no arbitrary shell commands, file paths or SMC-key writes in the protocol. The C layer separately restricts writes to fan target/mode keys the legacy force mask and Boolean Ftst handoff gate.

Policies are revalidated using fresh hardware readings. Ownership is recorded before writing so partial failures trigger restoration. The helper uses a continuous-clock lease, validates temperature every loop, retries failed restores and handles SIGTERM/INT/HUP by restoring before exit. The GUI also requests restoration on sleep and normal termination. There is no guarantee of restoration if the helper is killed, crashes, or the driver stops accepting writes.

## Preview limitations

- UID authentication allows other same-user processes to issue valid fan commands. There is no code-signature requirement on clients.
- The helper executable is launched from the local app bundle after administrator approval; it is not an installed, signature-pinned SMAppService daemon.
- SMC hardware control has been measured on an M4 Pro; other models and sleep/wake/fault recovery still require real-device verification.
- Mode and target readback are checked; actual physical fan acceleration is not verified by that check.
- Fan writes should not be used with another active fan-control utility.
- Ad-hoc signatures support local builds only; no Developer ID or notarization is included.

These limits must stay visible in preview releases. A stable release requires a reviewed helper lifecycle, stronger client authentication, and hardware/sleep/wake/fault testing.

Group requests validate every selected fan before the first write. Physical writes remain sequential; on failure, touched fans are returned to automatic and failed restoration stays tracked for retry.

Manual targets use hardware floors and ceilings. The global minimum override, its preference and helper command have been removed. Legacy below-floor fixed values are clamped on application; raw preset definitions are retained.

Fan Longevity Protection is an app preference imposing hardware RPM floors and bounded upward command changes, separate from the thermal safety guard. Disabling it leaves existing thermal/data/lease restoration intact. Helper protocol 12 carries the preference for manual policies and the live toggle. See [feature behavior and evidence](fan-longevity-protection.md).
