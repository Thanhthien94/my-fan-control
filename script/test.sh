#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/script/toolchain.sh"
if [[ "${DEVELOPER_DIR:-}" == /Library/Developer/CommandLineTools ]]; then
  # The CLT SwiftBuild test emitter omits this plugin for emit-module.
  MFC_SWIFT_ARGS+=(-Xswiftc -load-plugin-library -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib)
fi
swift test --disable-xctest --enable-swift-testing "${MFC_SWIFT_ARGS[@]}"
