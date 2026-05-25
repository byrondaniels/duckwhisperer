#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/Plume.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
FRAMEWORK_SRC="$ROOT_DIR/vendor/whisper-xcframework/build-apple/whisper.xcframework/macos-arm64_x86_64/whisper.framework"
FRAMEWORK_PARENT="$(dirname "$FRAMEWORK_SRC")"
MODEL_DST_DIR="$RESOURCES_DIR/Models"
TRANSLATION_DST_DIR="$RESOURCES_DIR/Translation"
MODULE_CACHE_DIR="$ROOT_DIR/build/module-cache"
SUPPORT_ROOT="${PLUME_SUPPORT_DIR:-$HOME/Library/Application Support/Plume}"
LEGACY_SUPPORT_ROOT="$HOME/Library/Application Support/Local Whisperer"
DEFAULT_MODEL_FILE="ggml-small.en.bin"
DEFAULT_MODEL_SRC="$SUPPORT_ROOT/Models/$DEFAULT_MODEL_FILE"
LEGACY_DEFAULT_MODEL_SRC="$LEGACY_SUPPORT_ROOT/Models/$DEFAULT_MODEL_FILE"
SWIFT_SOURCES=()
SIGNING_IDENTITY_WAS_SET=0

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

if [[ -n "${SIGNING_IDENTITY+x}" ]]; then
  SIGNING_IDENTITY_WAS_SET=1
else
  SIGNING_IDENTITY="$(find_default_signing_identity)"
fi

sign_app() {
  local identity="$1"
  if [[ "$identity" == "-" ]]; then
    echo "Signing Plume ad-hoc. Set SIGNING_IDENTITY to a stable code-signing identity to preserve Accessibility trust across rebuilds." >&2
  else
    echo "Signing Plume with: $identity" >&2
  fi
  codesign --force --deep --sign "$identity" "$APP_DIR"
}

if [[ ! -d "$FRAMEWORK_SRC" ]]; then
  echo "Missing whisper.framework. Download it with scripts/bootstrap_backend.sh first." >&2
  exit 1
fi

if [[ ("${INSTALL_DEFAULT_MODEL:-1}" == "1" || "${INSTALL_TRANSLATION:-0}" == "1") && ! -d "$SUPPORT_ROOT" && -d "$LEGACY_SUPPORT_ROOT" ]]; then
  mkdir -p "$(dirname "$SUPPORT_ROOT")"
  ditto "$LEGACY_SUPPORT_ROOT" "$SUPPORT_ROOT"
fi

if [[ "$APP_DIR" != "$ROOT_DIR/dist/Plume.app" ]]; then
  echo "Refusing to clean unexpected app directory: $APP_DIR" >&2
  exit 1
fi
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR" "$MODEL_DST_DIR" "$TRANSLATION_DST_DIR" "$MODULE_CACHE_DIR"
cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
while IFS= read -r source; do
  SWIFT_SOURCES+=("$source")
done < <(find "$ROOT_DIR/Sources/Plume" -name '*.swift' -print | sort)
if [[ "${#SWIFT_SOURCES[@]}" -eq 0 ]]; then
  echo "No Swift sources found under Sources/Plume." >&2
  exit 1
fi

swift \
  -module-cache-path "$MODULE_CACHE_DIR/icon-script" \
  "$ROOT_DIR/scripts/generate_plume_icon.swift" \
  "$RESOURCES_DIR/Plume.icns"
if [[ -f "$ROOT_DIR/Resources/UserGuide.html" ]]; then
  cp "$ROOT_DIR/Resources/UserGuide.html" "$RESOURCES_DIR/UserGuide.html"
fi
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
  -o "$MACOS_DIR/Plume"

if [[ "${BUNDLE_DEFAULT_MODEL:-0}" == "1" ]]; then
  if [[ ! -f "$DEFAULT_MODEL_SRC" && -f "$LEGACY_DEFAULT_MODEL_SRC" ]]; then
    DEFAULT_MODEL_SRC="$LEGACY_DEFAULT_MODEL_SRC"
  fi
  if [[ ! -f "$DEFAULT_MODEL_SRC" ]]; then
    "$ROOT_DIR/scripts/setup_default_model.sh"
  fi
  if [[ ! -f "$DEFAULT_MODEL_SRC" ]]; then
    echo "Default model was not found at $DEFAULT_MODEL_SRC after setup." >&2
    exit 1
  fi
  cp "$DEFAULT_MODEL_SRC" "$MODEL_DST_DIR/$DEFAULT_MODEL_FILE"
fi

sign_app "$SIGNING_IDENTITY"
if ! codesign --verify --deep --strict "$APP_DIR" >/dev/null 2>&1; then
  if [[ "$SIGNING_IDENTITY" != "-" && "$SIGNING_IDENTITY_WAS_SET" == "0" ]]; then
    echo "Auto-selected signing identity did not pass strict verification; falling back to ad-hoc signing." >&2
    sign_app "-"
    codesign --verify --deep --strict "$APP_DIR"
  else
    echo "Plume signature verification failed for SIGNING_IDENTITY=$SIGNING_IDENTITY" >&2
    codesign --verify --deep --strict "$APP_DIR"
    exit 1
  fi
fi

if [[ "${INSTALL_DEFAULT_MODEL:-1}" == "1" ]]; then
  "$ROOT_DIR/scripts/setup_default_model.sh"
fi

if [[ "${INSTALL_TRANSLATION:-0}" == "1" ]]; then
  "$ROOT_DIR/scripts/setup_local_translation.sh"
fi

echo "$APP_DIR"
