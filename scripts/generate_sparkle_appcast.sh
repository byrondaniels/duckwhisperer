#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVES_DIR="${1:-$ROOT_DIR/release}"
ACCOUNT="${SPARKLE_ACCOUNT:-duckwhisperer}"
DOWNLOAD_URL_PREFIX="${SPARKLE_DOWNLOAD_URL_PREFIX:-}"
RELEASE_NOTES_URL_PREFIX="${SPARKLE_RELEASE_NOTES_URL_PREFIX:-}"
LINK_URL="${SPARKLE_LINK_URL:-https://github.com/byrondaniels/duckwhisperer}"
GENERATE_APPCAST="$ROOT_DIR/vendor/Sparkle/bin/generate_appcast"

"$ROOT_DIR/scripts/bootstrap_sparkle.sh" >/dev/null

if [[ ! -x "$GENERATE_APPCAST" ]]; then
  echo "Missing Sparkle generate_appcast tool. Run scripts/bootstrap_sparkle.sh first." >&2
  exit 1
fi

if ! find "$ARCHIVES_DIR" -maxdepth 1 -type f \( -name '*.dmg' -o -name '*.zip' \) | grep -q .; then
  echo "No DMG or ZIP update archives found in $ARCHIVES_DIR." >&2
  exit 1
fi

args=(
  "--account" "$ACCOUNT"
  "--link" "$LINK_URL"
)

if [[ -n "$DOWNLOAD_URL_PREFIX" ]]; then
  args+=("--download-url-prefix" "$DOWNLOAD_URL_PREFIX")
fi

if [[ -n "$RELEASE_NOTES_URL_PREFIX" ]]; then
  args+=("--release-notes-url-prefix" "$RELEASE_NOTES_URL_PREFIX")
fi

"$GENERATE_APPCAST" "${args[@]}" "$ARCHIVES_DIR"

cat <<EOF

Sparkle appcast generated:
$ARCHIVES_DIR/appcast.xml

Publish appcast.xml at the URL configured by SPARKLE_FEED_URL.
EOF
