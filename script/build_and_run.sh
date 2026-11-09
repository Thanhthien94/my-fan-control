#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/script/toolchain.sh"
MODE="${1:-run}"
case "$MODE" in run|--verify|--build-only|--debug|--logs|--telemetry) ;; *) echo "Usage: $0 [run|--verify|--build-only|--debug|--logs|--telemetry]" >&2; exit 2;; esac
APP_NAME=MyFanControl
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
if [[ "$MODE" != --build-only ]] && /usr/bin/pgrep -x "$APP_NAME" >/dev/null; then
  # Ask our own app to restore automatic control before replacing its executable.
  /usr/bin/osascript -e 'tell application id "vn.thiendev.myfancontrol" to quit' || exit 1
  for ((i=0;i<30;i++)); do
    if ! /usr/bin/pgrep -x "$APP_NAME" >/dev/null; then break; fi
    sleep 0.2
  done
  if /usr/bin/pgrep -x "$APP_NAME" >/dev/null; then echo "App is still restoring controls. Close it before rebuilding." >&2; exit 1; fi
fi
CONFIGURATION="${MFC_CONFIGURATION:-debug}"
swift build --configuration "$CONFIGURATION" ${MFC_SWIFT_ARGS[@]+"${MFC_SWIFT_ARGS[@]}"}
BIN_DIR="$(swift build --configuration "$CONFIGURATION" ${MFC_SWIFT_ARGS[@]+"${MFC_SWIFT_ARGS[@]}"} --show-bin-path)"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$ROOT_DIR/assets/brand/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "$ROOT_DIR/LICENSE" "$APP_BUNDLE/Contents/Resources/LICENSE.txt"
cp "$ROOT_DIR/THIRD_PARTY_NOTICES.md" "$APP_BUNDLE/Contents/Resources/THIRD_PARTY_NOTICES.md"
cp "$BIN_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$BIN_DIR/fanctl" "$APP_BUNDLE/Contents/MacOS/fanctl"
for RESOURCE in "$BIN_DIR/"*.bundle; do
  [[ -d "$RESOURCE" ]] || continue
  /usr/bin/ditto "$RESOURCE" "$APP_BUNDLE/Contents/Resources/$(basename "$RESOURCE")"
done
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MyFanControl</string>
<key>CFBundleIdentifier</key><string>vn.thiendev.myfancontrol</string>
<key>CFBundleName</key><string>My Fan Control</string>
<key>CFBundleDisplayName</key><string>My Fan Control</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>vi</string></array>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
chmod +x "$APP_BUNDLE/Contents/MacOS/"*
/usr/bin/codesign --force --sign - "$APP_BUNDLE/Contents/MacOS/fanctl"
/usr/bin/codesign --force --sign - "$APP_BUNDLE"
case "$MODE" in
  --build-only) echo "$APP_BUNDLE" ;;
  --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ;;
  --logs) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'process == "MyFanControl"' ;;
  --telemetry) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'subsystem == "vn.thiendev.myfancontrol"' ;;
  --verify) /usr/bin/open -n "$APP_BUNDLE"; sleep 2; /usr/bin/pgrep -x "$APP_NAME" ;;
  run) /usr/bin/open -n "$APP_BUNDLE" ;;
esac
