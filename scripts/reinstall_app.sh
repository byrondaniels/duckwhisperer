#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DuckWhisperer.app"
APP_SRC="$ROOT_DIR/dist/$APP_NAME"
APP_DST="${DUCKWHISPERER_INSTALL_DIR:-/Applications}/$APP_NAME"
FRAMEWORK_DIR="$ROOT_DIR/vendor/whisper-xcframework/build-apple/whisper.xcframework"

cd "$ROOT_DIR"

if [[ ! -d "$FRAMEWORK_DIR" ]]; then
  echo "Preparing whisper.cpp backend..."
  ./scripts/bootstrap_backend.sh
fi

echo "Rebuilding DuckWhisperer without reinstalling runtime models..."
INSTALL_DEFAULT_MODEL=0 INSTALL_TRANSLATION=0 ./scripts/build_app.sh

if pgrep -x DuckWhisperer >/dev/null 2>&1; then
  echo "Stopping running DuckWhisperer..."
  osascript -e 'tell application "DuckWhisperer" to quit' >/dev/null 2>&1 || true
  sleep 1
  if pgrep -x DuckWhisperer >/dev/null 2>&1; then
    kill $(pgrep -x DuckWhisperer) >/dev/null 2>&1 || true
  fi
fi

echo "Installing $APP_NAME to $APP_DST..."
ditto "$APP_SRC" "$APP_DST"

echo "Refreshing macOS app registration..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DST" || true

echo "Launching DuckWhisperer..."
open "$APP_DST"

cat <<EOF

DuckWhisperer was reinstalled.

If this build was ad-hoc signed and automatic paste stops working, toggle DuckWhisperer off/on in:
System Settings -> Privacy & Security -> Accessibility

To reduce Accessibility resets across rebuilds, sign with a stable identity:
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/reinstall_app.sh
EOF
