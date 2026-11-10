# Native status-menu hover stability — 0.3.3 preview candidate

The reported ghost highlight occurred while menu telemetry changed at the monitoring cadence. The status menu now renders detached presentation values during native NSMenu tracking instead of observing live telemetry rows.

FanMenuSession is a small AppKit notification bridge. It recognizes the app’s status menu through its dashboard action, captures current data when tracking begins, preserves that snapshot through nested preset menus and releases it when tracking ends. Observer ownership is explicit and the store reference is weak. The status-item label also uses the held snapshot while the menu is open to keep its anchor width stable.

The menu states that its readings are taken at opening. Closing/reopening refreshes the readings. Monitoring/history, helper heartbeat and safety logic are not paused or replaced; menu actions still use the live store and existing command validation. Other native menus do not freeze the readout. No new persistent service or dependency is added.

Validation: 101 tests (including snapshot lifetime, nested preset menus and unrelated-menu isolation); 325 matching VI/EN strings; optimized native build and strict signature checks. Actual process logs confirmed status_menu_tracking_begin/status_menu_tracking_end; the user confirmed the hover behavior after reopening the candidate menu. No claim of a new physical fan-control test is made.

Tracking logs are limited to event names and a debug match boolean, under subsystem vn.thiendev.myfancontrol / category MenuTracking. No sensor values, preset names or private payloads are logged.
