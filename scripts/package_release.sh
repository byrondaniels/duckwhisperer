#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/DuckWhisperer.app"
RELEASE_DIR="$ROOT_DIR/release"
STAGING_ROOT="$ROOT_DIR/build/release-staging"
PACKAGE_FORMAT="${PACKAGE_FORMAT:-dmg}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT_DIR/Info.plist")"
ARTIFACT_BASE="DuckWhisperer-${VERSION}-${BUILD}"
DEFAULT_MODEL="$APP_DIR/Contents/Resources/Models/ggml-small.en.bin"
RELEASE_NOTES="$RELEASE_DIR/$ARTIFACT_BASE-release-notes.md"

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

write_start_here() {
  local output_path="$1"
  cat >"$output_path" <<'EOF'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Start Here - DuckWhisperer</title>
  <style>
    color-scheme: light dark;
    body {
      margin: 0;
      font: 16px/1.5 -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", Arial, sans-serif;
      background: Canvas;
      color: CanvasText;
    }
    main {
      max-width: 760px;
      margin: 0 auto;
      padding: 44px 28px 56px;
    }
    h1 {
      margin: 0 0 10px;
      font-size: 3rem;
      line-height: 1;
      letter-spacing: 0;
    }
    h2 {
      margin: 28px 0 8px;
      font-size: 1.15rem;
      letter-spacing: 0;
    }
    p {
      margin: 0 0 12px;
      max-width: 660px;
    }
    li + li {
      margin-top: 8px;
    }
    code {
      padding: 0.1rem 0.32rem;
      border-radius: 6px;
      background: rgba(127, 127, 127, 0.16);
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 0.92em;
    }
  </style>
</head>
<body>
  <main>
    <h1>Install DuckWhisperer</h1>
    <p>Drag <code>DuckWhisperer.app</code> onto <code>Applications</code>, then open it from Applications.</p>

    <h2>First Run</h2>
    <ol>
      <li>Open the menu-bar DuckWhisperer icon.</li>
      <li>Choose <code>Finish Setup...</code> for the guided setup checks.</li>
      <li>Grant Microphone and Paste-Back permissions.</li>
      <li>Choose <code>Try It Here...</code> for a quick test.</li>
    </ol>

    <h2>Shortcut</h2>
    <p>Press <code>Option+Space</code> to start recording, then press <code>Option+Space</code> again to stop and paste. Press <code>Escape</code> to cancel.</p>

    <h2>What Is Included</h2>
    <p>This app includes Best Accuracy English dictation. Extra language and style assets are optional downloads inside DuckWhisperer.</p>

    <h2>If Paste-Back Fails</h2>
    <p>Your text is copied and safe. Use <code>Paste Again</code>, <code>Copy</code>, <code>Try In DuckWhisperer</code>, or <code>Fix Permission</code> in the recovery window.</p>
  </main>
</body>
</html>
EOF
}

write_release_notes() {
  local package_list="$1"
  cat >"$RELEASE_NOTES" <<EOF
# DuckWhisperer $VERSION ($BUILD) Release Notes

## Artifacts

$package_list

## User Install Flow

1. Open the DMG.
2. Drag DuckWhisperer.app to Applications.
3. Open DuckWhisperer from Applications.
4. Open Finish Setup from the menu-bar icon.
5. Grant Microphone and Paste-Back permissions.
6. Press Option+Space to start and stop dictation.

## Included Assets

- Bundled default speech model: Best Accuracy English (ggml-small.en.bin).
- Bundled user guide: Resources/UserGuide.html.
- Optional non-English speech, translation, and Enhanced Robot assets are not included. DuckWhisperer asks before downloading them.
- First-run setup checks, paste-back diagnostics, and support bundle export are included in the app.

## Signing

The app was signed by scripts/build_app.sh. Use SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" for public releases. Ad-hoc builds are fine for local testing but may trigger macOS permission prompts after rebuilds.

## Verification

Run these before publishing:

- ./scripts/verify.sh
- ./scripts/package_release.sh
- Mount the DMG and drag DuckWhisperer.app into Applications on a clean user account or a second Mac.
- Open Try It Here..., record once, and confirm paste-back works in TextEdit or Notes after Accessibility is enabled.
EOF
}

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

rm -rf "$ROOT_DIR/build/module-cache"

mkdir -p "$RELEASE_DIR"
created_packages=()

if [[ "$PACKAGE_FORMAT" == "zip" || "$PACKAGE_FORMAT" == "both" ]]; then
  ZIP_PATH="$RELEASE_DIR/$ARTIFACT_BASE.zip"
  rm -f "$ZIP_PATH"
  echo "Creating $ZIP_PATH..."
  ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"
  du -h "$ZIP_PATH"
  created_packages+=("- $ZIP_PATH")
fi

if [[ "$PACKAGE_FORMAT" == "dmg" || "$PACKAGE_FORMAT" == "both" ]]; then
  STAGING_DIR="$STAGING_ROOT/$ARTIFACT_BASE"
  DMG_PATH="$RELEASE_DIR/$ARTIFACT_BASE.dmg"
  mkdir -p "$STAGING_DIR"
  if ! cp -cR "$APP_DIR" "$STAGING_DIR/DuckWhisperer.app" 2>/dev/null; then
    rm -rf "$STAGING_DIR/DuckWhisperer.app"
    ditto "$APP_DIR" "$STAGING_DIR/DuckWhisperer.app"
  fi
  ln -s /Applications "$STAGING_DIR/Applications"
  write_start_here "$STAGING_DIR/Start Here.html"
  rm -f "$DMG_PATH"
  echo "Creating $DMG_PATH..."
  hdiutil create \
    -volname "DuckWhisperer" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"
  du -h "$DMG_PATH"
  created_packages+=("- $DMG_PATH")
fi

write_release_notes "$(printf '%s\n' "${created_packages[@]}")"

cat <<EOF

Release package created in:
$RELEASE_DIR

Release notes:
$RELEASE_NOTES

This package includes Best Accuracy dictation inside DuckWhisperer.app.
Non-English speech models, translator add-ons, and Enhanced Robot assets remain optional and install only after user approval.
EOF
