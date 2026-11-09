# Static analysis notes

Target: installed Macs Fan Control 1.5.21. Analysis performed with REA 6.4.0 `inspect-macho`, without launching the target, modifying its executable, or inspecting license mechanisms.

| Observation | Evidence |
| --- | --- |
| Main application links Qt 5.15.17, IOKit, Security and ServiceManagement. Imports include `IOConnectCallStructMethod`, `IOServiceOpen`, `SMJobBless`, and XPC client functions. | REA `ev_dc8d377fb04319546518d21b1b55465d94b71b6f552934b79eb8fe5a84de4f4b` |
| A separately shipped `com.crystalidea.macsfancontrol.smcwrite` executable imports IOKit calls, XPC server functions and audit-token access. | REA `ev_904e89d524fc0a3ee7181fdb3f5b4e7f09d085e99fb255df391e3cb4dd9bf24a` |

These are linkage/import observations. They suggest a separate privileged hardware-write component; they do not establish control flow, algorithms, protocol semantics, or runtime behavior. REA MCP's native subprocess commands failed in this session; the installed CLI completed Mach-O inspection. No decompiler engine was configured, so function bodies were not recovered.

The new application's SwiftUI interface, policy engine, bounded Unix-socket protocol, helper lifecycle and tests are independent design choices. No third-party executable, helper, UI resource or source is copied into the repository. Complete local evidence and hardware snapshots remain excluded from Git because they include host paths; the portable summary above records only relevant architectural facts and evidence IDs.
