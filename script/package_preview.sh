#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/script/toolchain.sh"
git rev-parse --is-inside-work-tree >/dev/null
if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then
  echo "Package releases from a clean committed tree." >&2; exit 1
fi
VERSION="$(cat VERSION)"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9.]+)?$ ]]; then echo "Invalid VERSION" >&2; exit 1; fi
MFC_CONFIGURATION=release ./script/build_and_run.sh --build-only
APP="$ROOT_DIR/dist/MyFanControl.app"
ARCH="$(/usr/bin/lipo -archs "$APP/Contents/MacOS/MyFanControl")"
if [[ "$ARCH" != arm64 ]]; then echo "This preview supports arm64 only." >&2; exit 1; fi
/usr/bin/codesign --verify --deep --strict "$APP"
STAGE="$(mktemp -d "$ROOT_DIR/dist/package-stage.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
/usr/bin/ditto --norsrc --noextattr --noacl "$APP" "$STAGE/MyFanControl.app"
/usr/bin/codesign --verify --deep --strict "$STAGE/MyFanControl.app"
ln -s /Applications "$STAGE/Applications"
cp INSTALL.md "$STAGE/START HERE.md"
cp LICENSE THIRD_PARTY_NOTICES.md PRIVACY.md PRIVACY-vi.md "$STAGE/"
DMG="$ROOT_DIR/dist/MyFanControl-$VERSION-arm64.dmg"
ZIP="$ROOT_DIR/dist/MyFanControl-$VERSION-arm64.zip"
/usr/bin/hdiutil create -quiet -ov -volname "My Fan Control Preview" -srcfolder "$STAGE" -format UDZO "$DMG"
/usr/bin/ditto -c -k --norsrc --noextattr --noacl --keepParent "$STAGE/MyFanControl.app" "$ZIP"
(cd "$ROOT_DIR/dist" && /usr/bin/shasum -a 256 "$(basename "$DMG")" "$(basename "$ZIP")" > SHA256SUMS.txt)
echo "$DMG"
echo "$ZIP"
