#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPARKLE_VERSION="${SPARKLE_VERSION:-2.9.2}"
SPARKLE_SHA256="${SPARKLE_SHA256:-1cb340cbbef04c6c0d162078610c25e2221031d794a3449d89f2f56f4df77c95}"
SPARKLE_URL="${SPARKLE_URL:-https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz}"
VENDOR_DIR="$ROOT_DIR/vendor/Sparkle"
FRAMEWORK_DIR="$VENDOR_DIR/Sparkle.framework"
BIN_DIR="$VENDOR_DIR/bin"
ARCHIVE_DIR="$ROOT_DIR/build/sparkle"
ARCHIVE_PATH="$ARCHIVE_DIR/Sparkle-$SPARKLE_VERSION.tar.xz"
EXTRACT_DIR="$ARCHIVE_DIR/Sparkle-$SPARKLE_VERSION"

if [[ -d "$FRAMEWORK_DIR" && -x "$BIN_DIR/generate_appcast" && -x "$BIN_DIR/generate_keys" ]]; then
  echo "Sparkle $SPARKLE_VERSION is already bootstrapped."
  exit 0
fi

mkdir -p "$ARCHIVE_DIR"
if [[ ! -f "$ARCHIVE_PATH" ]]; then
  echo "Downloading Sparkle $SPARKLE_VERSION..."
  curl -L "$SPARKLE_URL" -o "$ARCHIVE_PATH"
fi

actual_sha="$(shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1}')"
if [[ "$actual_sha" != "$SPARKLE_SHA256" ]]; then
  echo "Sparkle archive checksum mismatch." >&2
  echo "Expected: $SPARKLE_SHA256" >&2
  echo "Actual:   $actual_sha" >&2
  exit 1
fi

rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"
tar -xf "$ARCHIVE_PATH" -C "$EXTRACT_DIR"

rm -rf "$VENDOR_DIR"
mkdir -p "$VENDOR_DIR"
ditto "$EXTRACT_DIR/Sparkle.framework" "$FRAMEWORK_DIR"
ditto "$EXTRACT_DIR/bin" "$BIN_DIR"

echo "Sparkle $SPARKLE_VERSION bootstrapped at $VENDOR_DIR"
