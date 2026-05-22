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
SWIFT_SOURCES=()

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

codesign --force --deep --sign - "$APP_DIR"

if [[ "${INSTALL_DEFAULT_MODEL:-1}" == "1" ]]; then
  "$ROOT_DIR/scripts/setup_default_model.sh"
fi

if [[ "${INSTALL_TRANSLATION:-0}" == "1" ]]; then
  "$ROOT_DIR/scripts/setup_local_translation.sh"
fi

echo "$APP_DIR"
