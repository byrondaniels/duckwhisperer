#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL_FILE="ggml-small.en.bin"
EXPECTED_SHA="db8a495a91d927739e50b3fc1cc4c6b8f6c2d022"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$MODEL_FILE"
SUPPORT_ROOT="${PLUME_SUPPORT_DIR:-$HOME/Library/Application Support/Plume}"
LEGACY_SUPPORT_ROOT="$HOME/Library/Application Support/Local Whisperer"
MODEL_DIR="$SUPPORT_ROOT/Models"
DEST="$MODEL_DIR/$MODEL_FILE"
CACHE_SRC="$ROOT_DIR/Resources/Models/$MODEL_FILE"

if [[ ! -d "$SUPPORT_ROOT" && -d "$LEGACY_SUPPORT_ROOT" ]]; then
  mkdir -p "$(dirname "$SUPPORT_ROOT")"
  ditto "$LEGACY_SUPPORT_ROOT" "$SUPPORT_ROOT"
fi

mkdir -p "$MODEL_DIR"

sha1_of() {
  shasum -a 1 "$1" | awk '{print $1}'
}

if [[ -f "$DEST" ]] && [[ "$(sha1_of "$DEST")" == "$EXPECTED_SHA" ]]; then
  echo "Default model already installed at $DEST"
  exit 0
fi

if [[ -f "$CACHE_SRC" ]] && [[ "$(sha1_of "$CACHE_SRC")" == "$EXPECTED_SHA" ]]; then
  cp "$CACHE_SRC" "$DEST"
  echo "Installed default model from local cache: $DEST"
  exit 0
fi

PARTIAL="$DEST.download"
curl --fail -L --continue-at - "$MODEL_URL" -o "$PARTIAL"

actual_sha="$(sha1_of "$PARTIAL")"
if [[ "$actual_sha" != "$EXPECTED_SHA" ]]; then
  rm -f "$PARTIAL"
  echo "Checksum mismatch for $MODEL_FILE." >&2
  echo "Expected: $EXPECTED_SHA" >&2
  echo "Actual:   $actual_sha" >&2
  exit 1
fi

mv "$PARTIAL" "$DEST"
echo "Installed default model: $DEST"
