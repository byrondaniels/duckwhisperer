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
ENABLE_SPARKLE="${ENABLE_SPARKLE:-1}"
SPARKLE_VENDOR_DIR="$ROOT_DIR/vendor/Sparkle"
SPARKLE_FRAMEWORK_SRC="$SPARKLE_VENDOR_DIR/Sparkle.framework"
SPARKLE_FRAMEWORK_PARENT="$SPARKLE_VENDOR_DIR"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://byrondaniels.github.io/duckwhisperer/appcast.xml}"
SPARKLE_PUBLIC_ED_KEY_FILE="${SPARKLE_PUBLIC_ED_KEY_FILE:-$ROOT_DIR/.sparkle-public-ed-key}"
MODEL_DST_DIR="$RESOURCES_DIR/Models"
TRANSLATION_DST_DIR="$RESOURCES_DIR/Translation"
MODULE_CACHE_DIR="$ROOT_DIR/build/module-cache"
SUPPORT_ROOT="${DUCKWHISPERER_SUPPORT_DIR:-${PLUME_SUPPORT_DIR:-$HOME/Library/Application Support/DuckWhisperer}}"
LEGACY_SUPPORT_ROOTS=(
  "$HOME/Library/Application Support/Plume"
  "$HOME/Library/Application Support/Local Whisperer"
)
DEFAULT_MODEL_FILE="ggml-small.en.bin"
DEFAULT_MODEL_SRC="$SUPPORT_ROOT/Models/$DEFAULT_MODEL_FILE"
SWIFT_SOURCES=()
SWIFTC_FRAMEWORK_ARGS=()
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
    echo "Signing DuckWhisperer ad-hoc. Set SIGNING_IDENTITY to a stable code-signing identity to preserve Accessibility trust across rebuilds." >&2
  else
    echo "Signing DuckWhisperer with: $identity" >&2
  fi
  codesign --force --deep --sign "$identity" "$APP_DIR"
}

sparkle_public_key() {
  if [[ -n "${SPARKLE_PUBLIC_ED_KEY:-}" ]]; then
    printf '%s\n' "$SPARKLE_PUBLIC_ED_KEY"
    return
  fi

  if [[ -f "$SPARKLE_PUBLIC_ED_KEY_FILE" ]]; then
    tr -d '\n' < "$SPARKLE_PUBLIC_ED_KEY_FILE"
    printf '\n'
  fi
}

set_plist_string() {
  local key="$1"
  local value="$2"
  local plist="$CONTENTS_DIR/Info.plist"
  /usr/libexec/PlistBuddy -c "Delete :$key" "$plist" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist"
}

if [[ ! -d "$FRAMEWORK_SRC" ]]; then
  echo "Missing whisper.framework. Download it with scripts/bootstrap_backend.sh first." >&2
  exit 1
fi

if [[ "$ENABLE_SPARKLE" == "1" ]]; then
  if [[ ! -d "$SPARKLE_FRAMEWORK_SRC" ]]; then
    "$ROOT_DIR/scripts/bootstrap_sparkle.sh"
  fi
  if [[ ! -d "$SPARKLE_FRAMEWORK_SRC" ]]; then
    echo "Missing Sparkle.framework. Run scripts/bootstrap_sparkle.sh first." >&2
    exit 1
  fi
  SWIFTC_FRAMEWORK_ARGS+=(
    -F "$SPARKLE_FRAMEWORK_PARENT"
    -framework Sparkle
  )
fi

if [[ ("${INSTALL_DEFAULT_MODEL:-1}" == "1" || "${INSTALL_TRANSLATION:-0}" == "1") && ! -d "$SUPPORT_ROOT" ]]; then
  for legacy_support_root in "${LEGACY_SUPPORT_ROOTS[@]}"; do
    if [[ -d "$legacy_support_root" ]]; then
      mkdir -p "$(dirname "$SUPPORT_ROOT")"
      ditto "$legacy_support_root" "$SUPPORT_ROOT"
      break
    fi
  done
fi

if [[ "$APP_DIR" != "$ROOT_DIR/dist/DuckWhisperer.app" ]]; then
  echo "Refusing to clean unexpected app directory: $APP_DIR" >&2
  exit 1
fi
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR" "$MODEL_DST_DIR" "$TRANSLATION_DST_DIR" "$MODULE_CACHE_DIR"
cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
if [[ "$ENABLE_SPARKLE" == "1" ]]; then
  set_plist_string "SUFeedURL" "$SPARKLE_FEED_URL"
  public_key="$(sparkle_public_key)"
  if [[ -n "$public_key" ]]; then
    set_plist_string "SUPublicEDKey" "$public_key"
  else
    echo "Sparkle is linked, but SUPublicEDKey is not configured. Run scripts/setup_sparkle_keys.sh or set SPARKLE_PUBLIC_ED_KEY for release builds." >&2
  fi
fi
while IFS= read -r source; do
  SWIFT_SOURCES+=("$source")
done < <(find "$ROOT_DIR/Sources/DuckWhisperer" -name '*.swift' -print | sort)
if [[ "${#SWIFT_SOURCES[@]}" -eq 0 ]]; then
  echo "No Swift sources found under Sources/DuckWhisperer." >&2
  exit 1
fi

swift \
  -module-cache-path "$MODULE_CACHE_DIR/icon-script" \
  "$ROOT_DIR/scripts/generate_duckwhisperer_icon.swift" \
  "$RESOURCES_DIR/DuckWhisperer.icns"
if [[ -f "$ROOT_DIR/Resources/UserGuide.html" ]]; then
  cp "$ROOT_DIR/Resources/UserGuide.html" "$RESOURCES_DIR/UserGuide.html"
fi
if [[ -f "$ROOT_DIR/Resources/DuckWhispererOption3.png" ]]; then
  cp "$ROOT_DIR/Resources/DuckWhispererOption3.png" "$RESOURCES_DIR/DuckWhispererOption3.png"
fi
if [[ -f "$ROOT_DIR/Resources/DuckWhispererOption3Hud.png" ]]; then
  cp "$ROOT_DIR/Resources/DuckWhispererOption3Hud.png" "$RESOURCES_DIR/DuckWhispererOption3Hud.png"
fi
ditto "$FRAMEWORK_SRC" "$FRAMEWORKS_DIR/whisper.framework"
if [[ "$ENABLE_SPARKLE" == "1" ]]; then
  ditto "$SPARKLE_FRAMEWORK_SRC" "$FRAMEWORKS_DIR/Sparkle.framework"
fi
find "$MODEL_DST_DIR" -maxdepth 1 -type f -name 'ggml-*.bin' -delete
cp "$ROOT_DIR/translation/translate_local.py" "$TRANSLATION_DST_DIR/translate_local.py"

swiftc \
  -swift-version 5 \
  -O \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -F "$FRAMEWORK_PARENT" \
  -framework whisper \
  "${SWIFTC_FRAMEWORK_ARGS[@]}" \
  -framework AppKit \
  -framework ApplicationServices \
  -framework AVFoundation \
  -framework Carbon \
  -framework QuartzCore \
  -Xlinker -weak_framework \
  -Xlinker Translation \
  -Xlinker -rpath \
  -Xlinker "@executable_path/../Frameworks" \
  "${SWIFT_SOURCES[@]}" \
  -o "$MACOS_DIR/DuckWhisperer"

if [[ "${BUNDLE_DEFAULT_MODEL:-0}" == "1" ]]; then
  if [[ ! -f "$DEFAULT_MODEL_SRC" ]]; then
    for legacy_support_root in "${LEGACY_SUPPORT_ROOTS[@]}"; do
      legacy_default_model_src="$legacy_support_root/Models/$DEFAULT_MODEL_FILE"
      if [[ -f "$legacy_default_model_src" ]]; then
        DEFAULT_MODEL_SRC="$legacy_default_model_src"
        break
      fi
    done
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
    echo "DuckWhisperer signature verification failed for SIGNING_IDENTITY=$SIGNING_IDENTITY" >&2
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
