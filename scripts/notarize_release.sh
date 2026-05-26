#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT_DIR/Info.plist")"
DMG_PATH="${1:-$ROOT_DIR/release/DuckWhisperer-${VERSION}-${BUILD}.dmg}"

require_command() {
  local command_name="$1"
  local install_hint="$2"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    echo "$install_hint" >&2
    exit 1
  fi
}

require_command xcrun "Install Xcode or Xcode Command Line Tools."

if [[ ! -f "$DMG_PATH" ]]; then
  echo "Missing DMG: $DMG_PATH" >&2
  echo "Create it first with ./scripts/package_release.sh" >&2
  exit 1
fi

submit_with_profile() {
  xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARYTOOL_PROFILE" \
    --wait
}

submit_with_credentials() {
  xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait
}

if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
  echo "Submitting $DMG_PATH for notarization with keychain profile: $NOTARYTOOL_PROFILE"
  submit_with_profile
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
  echo "Submitting $DMG_PATH for notarization with Apple ID credentials..."
  submit_with_credentials
else
  cat >&2 <<'EOF'
Missing notarization credentials.

Use either:
  NOTARYTOOL_PROFILE=duckwhisperer-release ./scripts/notarize_release.sh

or:
  APPLE_ID="you@example.com" APPLE_TEAM_ID="TEAMID" APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx" ./scripts/notarize_release.sh

Create a stored profile with:
  xcrun notarytool store-credentials duckwhisperer-release --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-password"
EOF
  exit 1
fi

echo "Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"

echo "Validating stapled DMG..."
xcrun stapler validate "$DMG_PATH"
spctl -a -t open --context context:primary-signature -v "$DMG_PATH"

echo "Notarized release is ready:"
echo "$DMG_PATH"
