#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/vendor"
XCFRAMEWORK_ZIP="$VENDOR_DIR/whisper-v1.8.4-xcframework.zip"
XCFRAMEWORK_DIR="$VENDOR_DIR/whisper-xcframework"

mkdir -p "$VENDOR_DIR"

if [[ ! -d "$XCFRAMEWORK_DIR/build-apple/whisper.xcframework" ]]; then
  curl -L \
    https://github.com/ggml-org/whisper.cpp/releases/download/v1.8.4/whisper-v1.8.4-xcframework.zip \
    -o "$XCFRAMEWORK_ZIP"
  ditto -x -k "$XCFRAMEWORK_ZIP" "$XCFRAMEWORK_DIR"
fi

echo "Backend ready."
