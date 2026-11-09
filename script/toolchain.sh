#!/usr/bin/env bash
# Source this file; prefer installed Command Line Tools without changing xcode-select.
if [[ -n "${MFC_DEVELOPER_DIR:-}" ]]; then
  export DEVELOPER_DIR="$MFC_DEVELOPER_DIR"
elif [[ -z "${DEVELOPER_DIR:-}" && -d /Library/Developer/CommandLineTools ]]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi
MFC_SWIFT_ARGS=()
if [[ -n "${MFC_SDK_PATH:-}" ]]; then
  MFC_SWIFT_ARGS+=(--sdk "$MFC_SDK_PATH")
elif [[ "${DEVELOPER_DIR:-}" == /Library/Developer/CommandLineTools && -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then
  # The installed 27.2 CLT SDK declares SwiftUIMacros but does not ship that plugin.
  MFC_SWIFT_ARGS+=(--sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk)
fi
