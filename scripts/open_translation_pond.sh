#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/tools"
BINARY="$BUILD_DIR/TranslationPond"
SOURCE="$ROOT_DIR/tools/apple_translation_pond/TranslationPond.swift"
MODULE_CACHE_DIR="$ROOT_DIR/build/module-cache"

mkdir -p "$BUILD_DIR" "$MODULE_CACHE_DIR"

swiftc \
  -parse-as-library \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -framework SwiftUI \
  -framework Translation \
  "$SOURCE" \
  -o "$BINARY"

echo "Opening Translation Pond..."
"$BINARY"
