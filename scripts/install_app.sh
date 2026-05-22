#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DuckWhisperer.app"
APP_SRC="$ROOT_DIR/dist/$APP_NAME"
APP_DST="${DUCKWHISPERER_INSTALL_DIR:-/Applications}/$APP_NAME"

cd "$ROOT_DIR"

echo "Preparing whisper.cpp backend..."
./scripts/bootstrap_backend.sh

echo "Building DuckWhisperer..."
./scripts/build_app.sh

echo "Installing $APP_NAME to $APP_DST..."
ditto "$APP_SRC" "$APP_DST"

echo "Refreshing macOS app registration..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DST" || true

echo "Launching DuckWhisperer..."
open "$APP_DST"

cat <<EOF

DuckWhisperer is installed.

Next steps:
1. Grant Microphone permission when macOS asks.
2. Enable DuckWhisperer in System Settings -> Privacy & Security -> Accessibility.
3. Press Option+Space once to start recording, then Option+Space again to stop and paste.

Runtime models live outside the repo at:
~/Library/Application Support/Local Whisperer
EOF
