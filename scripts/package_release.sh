#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/DuckWhisperer.app"
RELEASE_DIR="$ROOT_DIR/release"
STAGING_ROOT="$ROOT_DIR/build/release-staging"
PACKAGE_FORMAT="${PACKAGE_FORMAT:-zip}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT_DIR/Info.plist")"
ARTIFACT_BASE="DuckWhisperer-${VERSION}-${BUILD}"
DEFAULT_MODEL="$APP_DIR/Contents/Resources/Models/ggml-small.en.bin"

cd "$ROOT_DIR"

cleanup() {
  if [[ "$STAGING_ROOT" != "$ROOT_DIR/build/release-staging" ]]; then
    echo "Refusing to clean unexpected staging directory: $STAGING_ROOT" >&2
    return
  fi
  rm -rf "$STAGING_ROOT"
}
trap cleanup EXIT

case "$PACKAGE_FORMAT" in
  dmg | zip | both) ;;
  *)
    echo "PACKAGE_FORMAT must be dmg, zip, or both. Got: $PACKAGE_FORMAT" >&2
    exit 1
    ;;
esac

echo "Preparing whisper.cpp backend..."
./scripts/bootstrap_backend.sh

echo "Building self-contained DuckWhisperer app with bundled Best Accuracy dictation..."
BUNDLE_DEFAULT_MODEL=1 INSTALL_DEFAULT_MODEL=0 INSTALL_TRANSLATION=0 ./scripts/build_app.sh >/dev/null

if [[ ! -f "$DEFAULT_MODEL" ]]; then
  echo "Packaged app is missing bundled model: $DEFAULT_MODEL" >&2
  exit 1
fi

echo "Verifying app signature..."
codesign --verify --deep --strict "$APP_DIR"

mkdir -p "$RELEASE_DIR"

if [[ "$PACKAGE_FORMAT" == "zip" || "$PACKAGE_FORMAT" == "both" ]]; then
  ZIP_PATH="$RELEASE_DIR/$ARTIFACT_BASE.zip"
  rm -f "$ZIP_PATH"
  echo "Creating $ZIP_PATH..."
  ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"
  du -h "$ZIP_PATH"
fi

if [[ "$PACKAGE_FORMAT" == "dmg" || "$PACKAGE_FORMAT" == "both" ]]; then
  STAGING_DIR="$STAGING_ROOT/$ARTIFACT_BASE"
  DMG_PATH="$RELEASE_DIR/$ARTIFACT_BASE.dmg"
  mkdir -p "$STAGING_DIR"
  ditto "$APP_DIR" "$STAGING_DIR/DuckWhisperer.app"
  ln -s /Applications "$STAGING_DIR/Applications"
  rm -f "$DMG_PATH"
  echo "Creating $DMG_PATH..."
  hdiutil create \
    -volname "DuckWhisperer" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"
  du -h "$DMG_PATH"
fi

cat <<EOF

Release package created in:
$RELEASE_DIR

This package includes Best Accuracy dictation inside DuckWhisperer.app.
Non-English input models and French/Dutch translation remain optional and install only after user approval.
EOF
