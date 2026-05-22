#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/DuckWhisperer.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
FRAMEWORK_SRC="$ROOT_DIR/vendor/whisper-xcframework/build-apple/whisper.xcframework/macos-arm64_x86_64/whisper.framework"
FRAMEWORK_PARENT="$(dirname "$FRAMEWORK_SRC")"
MODEL_DST_DIR="$RESOURCES_DIR/Models"
TRANSLATION_DST_DIR="$RESOURCES_DIR/Translation"
MODULE_CACHE_DIR="$ROOT_DIR/build/module-cache"
SUPPORT_ROOT="${DUCKWHISPERER_SUPPORT_DIR:-${LOCAL_WHISPERER_SUPPORT_DIR:-$HOME/Library/Application Support/Local Whisperer}}"
DEFAULT_MODEL_FILE="ggml-small.en.bin"
DEFAULT_MODEL_SRC="$SUPPORT_ROOT/Models/$DEFAULT_MODEL_FILE"
SWIFT_SOURCES=()

find_default_signing_identity() {
  local identity
  identity="$(
    security find-identity -v -p codesigning 2>/dev/null |
      awk -F '"' '
        /Developer ID Application/ { selected = $2; exit }
        /Apple Development/ && !selected { selected = $2 }
        /Mac Developer/ && !selected { selected = $2 }
        /3rd Party Mac Developer Application/ && !selected { selected = $2 }
        END { if (selected) print selected }
      '
  )"

  if [[ -n "$identity" ]]; then
    printf '%s\n' "$identity"
  else
    printf '%s\n' "-"
  fi
}

SIGNING_IDENTITY="${SIGNING_IDENTITY:-$(find_default_signing_identity)}"

if [[ ! -d "$FRAMEWORK_SRC" ]]; then
  echo "Missing whisper.framework. Download it with scripts/bootstrap_backend.sh first." >&2
  exit 1
fi

if [[ "$APP_DIR" != "$ROOT_DIR/dist/DuckWhisperer.app" ]]; then
  echo "Refusing to clean unexpected app directory: $APP_DIR" >&2
  exit 1
fi
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR" "$MODEL_DST_DIR" "$TRANSLATION_DST_DIR" "$MODULE_CACHE_DIR"
cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
while IFS= read -r source; do
  SWIFT_SOURCES+=("$source")
done < <(find "$ROOT_DIR/Sources/LocalWhisperer" -name '*.swift' -print | sort)
if [[ "${#SWIFT_SOURCES[@]}" -eq 0 ]]; then
  echo "No Swift sources found under Sources/LocalWhisperer." >&2
  exit 1
fi

swift \
  -module-cache-path "$MODULE_CACHE_DIR/icon-script" \
  "$ROOT_DIR/scripts/generate_duck_icon.swift" \
  "$RESOURCES_DIR/DuckWhisperer.icns"
ditto "$FRAMEWORK_SRC" "$FRAMEWORKS_DIR/whisper.framework"
find "$MODEL_DST_DIR" -maxdepth 1 -type f -name 'ggml-*.bin' -delete
cp "$ROOT_DIR/translation/translate_local.py" "$TRANSLATION_DST_DIR/translate_local.py"

swiftc \
  -swift-version 5 \
  -O \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -F "$FRAMEWORK_PARENT" \
  -framework whisper \
  -framework AppKit \
  -framework ApplicationServices \
  -framework AVFoundation \
  -framework Carbon \
  -framework QuartzCore \
  -Xlinker -rpath \
  -Xlinker "@executable_path/../Frameworks" \
  "${SWIFT_SOURCES[@]}" \
  -o "$MACOS_DIR/DuckWhisperer"

if [[ "${BUNDLE_DEFAULT_MODEL:-0}" == "1" ]]; then
  "$ROOT_DIR/scripts/setup_default_model.sh"
  if [[ ! -f "$DEFAULT_MODEL_SRC" ]]; then
    echo "Default model was not found at $DEFAULT_MODEL_SRC after setup." >&2
    exit 1
  fi
  cp "$DEFAULT_MODEL_SRC" "$MODEL_DST_DIR/$DEFAULT_MODEL_FILE"
fi

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  echo "Signing DuckWhisperer ad-hoc. Set SIGNING_IDENTITY to a stable code-signing identity to preserve Accessibility trust across rebuilds." >&2
else
  echo "Signing DuckWhisperer with: $SIGNING_IDENTITY" >&2
fi
codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_DIR"

if [[ "${INSTALL_DEFAULT_MODEL:-1}" == "1" ]]; then
  "$ROOT_DIR/scripts/setup_default_model.sh"
fi

if [[ "${INSTALL_TRANSLATION:-0}" == "1" ]]; then
  "$ROOT_DIR/scripts/setup_local_translation.sh"
fi

echo "$APP_DIR"
