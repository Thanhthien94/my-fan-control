# Privilege boundary

The GUI is unprivileged. Monitoring uses an IOKit connection to AppleSMC. Fan writes are isolated in the `fanctl serve --uid <uid>` process, started on demand through macOS administrator authorization. No passwords are read or stored by the app.

The root helper binds a Unix socket under root-owned `/var/run`, refuses preexisting paths, applies mode 0600 for the selected UID and checks client credentials with `getpeereid`. The GUI checks that the server's UID is root. Requests are newline-delimited JSON, bounded to 4 KiB, with one-second send/receive deadlines. Only `status`, `configure`, `configureGroup`, `automatic` and `shutdown` are accepted. There are no arbitrary shell commands, file paths or SMC-key writes in the protocol. The C layer separately restricts writes to fan target/mode keys and the legacy force mask.

Policies are revalidated using fresh hardware readings. Ownership is recorded before writing so partial failures trigger restoration. The helper uses a continuous-clock lease, validates temperature every loop, retries failed restores and handles SIGTERM/INT/HUP by restoring before exit. The GUI also requests restoration on sleep and normal termination. There is no guarantee of restoration if the helper is killed, crashes, or the driver stops accepting writes.

## Preview limitations

- UID authentication allows other same-user processes to issue valid fan commands. There is no code-signature requirement on clients.
- The helper executable is launched from the local app bundle after administrator approval; it is not an installed, signature-pinned SMAppService daemon.
- SMC hardware behavior and write/readback ordering still require real-device verification.
- Mode and target readback are checked; actual physical fan acceleration is not verified by that check.
- Fan writes should not be used with another active fan-control utility.
- Ad-hoc signatures support local builds only; no Developer ID or notarization is included.

These limits must stay visible in preview releases. A stable release requires a reviewed helper lifecycle, stronger client authentication, and hardware/sleep/wake/fault testing.

Group requests validate every selected fan before the first write. Physical writes remain sequential; on failure, touched fans are returned to automatic and failed restoration stays tracked for retry.
