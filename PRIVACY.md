# Privacy

My Fan Control has no account, advertising, analytics, crash-upload, cloud-sync or automatic-update service. The app does not send fan readings, temperatures, presets, schedules or hardware identity to a server.

The app reads local AppleSMC fan/temperature channels and the chip's model string to choose community sensor labels. It checks the local running-app list to avoid conflicts with Macs Fan Control. These checks are used on the Mac and are not uploaded.

Presets, future schedule definitions, language and temperature-display preferences are saved in the app's local macOS preferences. Recent schedule activity and active fan ownership stay in process memory. A normal quit requests automatic mode; active control ownership is not resumed from disk.

The privileged helper runs locally, on demand, and communicates through a user-restricted Unix socket. macOS handles the administrator authentication dialog; the app does not read or store the user's password.

Choosing a sensor-source link opens the user's browser on GitHub. GitHub and the browser then apply their own privacy policies. Reporting an issue or attaching a snapshot is a deliberate user action; please redact private information before sharing diagnostics.

The image-generation tools used during development are not included in the app, and the app has no image-generation API or provider credential.
