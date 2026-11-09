# Privacy

My Fan Control has no account, advertising, analytics, crash-upload, cloud-sync or background automatic-update service. The app does not send fan readings, temperatures, presets, schedules or hardware identity to a server.

Only when you choose **Check for Updates**, the app makes a read-only HTTPS request to GitHub’s public Releases API. GitHub receives ordinary connection information, such as your IP address and a generic MyFanControl user agent. No account, token, hardware identity or configuration is included. The app never downloads, replaces or installs itself automatically.

The app reads local AppleSMC fan/temperature channels and the chip's model string to choose community sensor labels. It checks the local running-app list to avoid conflicts with Macs Fan Control. These checks are used on the Mac and are not uploaded.

Presets, future schedule definitions, language, menu bar and temperature-display preferences are saved in the app's local macOS preferences. Recent schedule activity and active fan ownership stay in process memory. A normal quit requests automatic mode; active control ownership is not resumed from disk.

The privileged helper runs locally, on demand, and communicates through a user-restricted Unix socket. macOS handles the administrator authentication dialog; the app does not read or store the user's password.

Exported backups contain preset names, schedule names and definitions. They stay in the file you choose. Imported schedules are disabled and never automatically apply fan control. Diagnostics exports include app/macOS versions, chip/model identifiers and read-only SMC capabilities, but exclude serial numbers, account names, presets and schedules. Review any file before deliberately sharing it.

An optional Open at Login setting registers the app with macOS only when you enable it. It starts monitoring without resuming manual control or asking for administrator authorization.

Choosing a help, release, issue or sensor-source link opens the user's browser on GitHub. GitHub and the browser then apply their own privacy policies. Reporting an issue or attaching a snapshot is a deliberate user action; please redact private information before sharing diagnostics.

The image-generation tools used during development are not included in the app, and the app has no image-generation API or provider credential.
