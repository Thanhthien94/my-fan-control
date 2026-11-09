# Scheduling behavior

The native schedule panel supports delayed starts, a single future date/time, and weekly repetition on selected weekdays. Each schedule snapshots a saved fixed-RPM or sensor preset, selects one or more fan IDs, and runs for 1–1440 minutes. Editing the saved preset later does not silently change an existing schedule.

The schedule list supports editing, enabling/disabling future starts, deleting schedules, canceling active runs and a recent activity log. Disabling a schedule affects future starts; use **Cancel & restore** to stop an already-running timer. Deleting an active schedule requests restoration first and retains it if restoration fails.

## Execution and ownership

- The GUI checks schedules during its two-second monitoring loop. This is not a launchd/always-on scheduler.
- Controls must already be authorized before the start. A scheduled event never displays an administrator prompt in the background.
- A scheduled run claims only available, automatically managed fans. It skips a conflicting manual policy or another active controller instead of overriding it.
- Saving an enabled schedule checks for overlapping time intervals on shared fans. Weekly checks include midnight/week wrapping and one-off dates far in the future; adjacent intervals are allowed. Runtime ownership checks remain the final guard, including around timezone/DST changes.
- Applying a manual policy cancels that fan's timer. A previous timer does not later restore over a newer manual setting.
- At completion or cancellation, the scheduler requests automatic mode only for fans still owned by that run. Failed restores are retried on subsequent polls.
- If one fan in a multi-fan start fails, already-started fans are rolled back; failed rollback attempts are retained for retry.
- The root helper continues to validate fresh temperatures and maintain its separate ten-second client lease. Scheduling does not bypass that boundary.

## Time, sleep and restart

The displayed timezone is the system's current timezone. Weekly dates use Calendar matching; nonexistent DST times resolve to the next valid local time, and repeated times prefer the first occurrence. Sensor and policy safety do not rely on wall-clock scheduling precision.

An active run uses a continuous-clock deadline for its duration, so setting the wall clock backwards cannot extend it. Absolute future schedules follow the system calendar. Starts missed by more than 60 seconds (including sleep or long delays) are logged and skipped. A backwards wall-clock adjustment does not re-run starts already observed by the current session.

On sleep or normal quit, the app requests automatic fan control and cancels active run ownership. The helper lease remains a separate best-effort fallback. Future schedules persist locally; active manual-control ownership is never restored from disk, and elapsed one-off jobs are disabled at launch. The app does not wake the Mac or run schedules when it is closed.

## Validation limits

The planner and scheduler execution are tested using injected clocks, isolated preferences and a fake hardware backend. Those tests can verify start/finish/cancel/override/rollback semantics without touching real SMC fans. Physical fan writes, real sleep/wake behavior and long-duration thermal operation remain unverified for this preview.
