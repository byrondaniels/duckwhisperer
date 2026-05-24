#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Plume.app"
APP_SRC="$ROOT_DIR/dist/$APP_NAME"
APP_DST="${PLUME_INSTALL_DIR:-${DUCKWHISPERER_INSTALL_DIR:-/Applications}}/$APP_NAME"
INSTALL_TRANSLATION="${INSTALL_TRANSLATION:-0}"
export INSTALL_TRANSLATION

cd "$ROOT_DIR"

require_command() {
  local command_name="$1"
  local install_hint="$2"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    echo "$install_hint" >&2
    exit 1
  fi
}

replace_app_bundle() {
  if [[ "$(basename "$APP_DST")" != "$APP_NAME" ]]; then
    echo "Refusing to replace unexpected app path: $APP_DST" >&2
    exit 1
  fi

  if [[ -e "$APP_DST" ]]; then
    rm -rf "$APP_DST"
  fi

  ditto "$APP_SRC" "$APP_DST"
}

stop_app() {
  local process_name="$1"
  local app_name="$2"
  if pgrep -x "$process_name" >/dev/null 2>&1; then
    echo "Stopping running $app_name..."
    osascript -e "tell application \"$app_name\" to quit" >/dev/null 2>&1 || true
    sleep 1
    if pgrep -x "$process_name" >/dev/null 2>&1; then
      kill $(pgrep -x "$process_name") >/dev/null 2>&1 || true
    fi
  fi
}

require_command swift "Install Xcode Command Line Tools: xcode-select --install"
require_command curl "Install curl or run on a standard macOS environment."

if [[ "$INSTALL_TRANSLATION" != "1" ]]; then
  echo "Skipping optional local translation runtime. Run scripts/setup_local_translation.sh later if you want French/Dutch translation."
fi

echo "Preparing whisper.cpp backend..."
./scripts/bootstrap_backend.sh

echo "Building Plume..."
./scripts/build_app.sh

stop_app Plume Plume
stop_app DuckWhisperer DuckWhisperer

echo "Installing $APP_NAME to $APP_DST..."
replace_app_bundle

echo "Refreshing macOS app registration..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DST" || true

echo "Launching Plume..."
open "$APP_DST"

cat <<EOF

Plume is installed.

Next steps:
1. Grant Microphone permission when macOS asks.
2. Enable Plume in System Settings -> Privacy & Security -> Accessibility.
3. Press Option+Space once to start recording, then Option+Space again to stop and paste.

Runtime models live outside the repo at:
~/Library/Application Support/Plume

Optional local translation is not installed by default. Add it later with:
./scripts/setup_local_translation.sh

For rebuilds that preserve Accessibility trust more reliably, sign with a stable identity:
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/reinstall_app.sh
EOF
