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
BUNDLE_DEFAULT_MODEL="${BUNDLE_DEFAULT_MODEL:-0}"
DEFAULT_MODEL="$APP_DIR/Contents/Resources/Models/ggml-small.en.bin"
RELEASE_NOTES="$RELEASE_DIR/$ARTIFACT_BASE-release-notes.md"
SPARKLE_RELEASE_NOTES="$RELEASE_DIR/$ARTIFACT_BASE.md"
SPARKLE_ARCHIVE_DIR="${SPARKLE_ARCHIVE_DIR:-$RELEASE_DIR/sparkle}"
SPARKLE_PUBLIC_ED_KEY_FILE="${SPARKLE_PUBLIC_ED_KEY_FILE:-$ROOT_DIR/.sparkle-public-ed-key}"

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

if [[ "${REQUIRE_SPARKLE_CONFIG:-0}" == "1" ]]; then
  if [[ -z "${SPARKLE_PUBLIC_ED_KEY:-}" && ! -f "$SPARKLE_PUBLIC_ED_KEY_FILE" ]]; then
    echo "Sparkle public key is required for this release." >&2
    echo "Run ./scripts/setup_sparkle_keys.sh or set SPARKLE_PUBLIC_ED_KEY." >&2
    exit 1
  fi
fi

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
    <p>This app downloads its English speech model on first launch (approval-gated). Extra language packs are optional downloads from inside DuckWhisperer.</p>

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

- Bundled user guide: Resources/UserGuide.html.
- Speech models (English and non-English) and translation packs are approval-gated downloads from inside DuckWhisperer. Nothing downloads without user consent.
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

if [[ "$BUNDLE_DEFAULT_MODEL" == "1" ]]; then
  echo "Building self-contained DuckWhisperer app with bundled Best Accuracy dictation..."
else
  echo "Building DuckWhisperer app; speech model will download on first launch..."
fi
BUNDLE_DEFAULT_MODEL="$BUNDLE_DEFAULT_MODEL" INSTALL_DEFAULT_MODEL=0 INSTALL_TRANSLATION=0 ./scripts/build_app.sh >/dev/null

if [[ "$BUNDLE_DEFAULT_MODEL" == "1" && ! -f "$DEFAULT_MODEL" ]]; then
  echo "Packaged app is missing bundled model: $DEFAULT_MODEL" >&2
  exit 1
fi

echo "Verifying app signature..."
codesign --verify --deep --strict "$APP_DIR"

rm -rf "$ROOT_DIR/build/module-cache"

mkdir -p "$RELEASE_DIR"
created_packages=()
created_package_paths=()

if [[ "$PACKAGE_FORMAT" == "zip" || "$PACKAGE_FORMAT" == "both" ]]; then
  ZIP_PATH="$RELEASE_DIR/$ARTIFACT_BASE.zip"
  rm -f "$ZIP_PATH"
  echo "Creating $ZIP_PATH..."
  ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"
  du -h "$ZIP_PATH"
  created_packages+=("- $ZIP_PATH")
  created_package_paths+=("$ZIP_PATH")
fi

if [[ "$PACKAGE_FORMAT" == "dmg" || "$PACKAGE_FORMAT" == "both" ]]; then
  STAGING_DIR="$STAGING_ROOT/$ARTIFACT_BASE"
  DMG_PATH="$RELEASE_DIR/$ARTIFACT_BASE.dmg"
  TEMP_DMG="$STAGING_ROOT/$ARTIFACT_BASE-temp.dmg"
  BACKGROUND_PNG="$STAGING_ROOT/dmg-background.png"
  VOLUME_NAME="DuckWhisperer"
  mkdir -p "$STAGING_DIR"
  if ! cp -cR "$APP_DIR" "$STAGING_DIR/DuckWhisperer.app" 2>/dev/null; then
    rm -rf "$STAGING_DIR/DuckWhisperer.app"
    ditto "$APP_DIR" "$STAGING_DIR/DuckWhisperer.app"
  fi
  ln -s /Applications "$STAGING_DIR/Applications"
  write_start_here "$STAGING_DIR/Start Here.html"

  echo "Generating DMG background..."
  /usr/bin/swift "$ROOT_DIR/scripts/generate_dmg_background.swift" "$BACKGROUND_PNG"

  echo "Creating writable DMG for layout..."
  rm -f "$DMG_PATH" "$TEMP_DMG"
  STAGING_SIZE_KB=$(du -sk "$STAGING_DIR" | awk '{print $1}')
  DMG_SIZE_KB=$(( STAGING_SIZE_KB + 20480 ))
  hdiutil create \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -size "${DMG_SIZE_KB}k" \
    "$TEMP_DMG" >/dev/null

  MOUNT_POINT="/Volumes/$VOLUME_NAME"
  hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" >/dev/null

  ditto "$STAGING_DIR/DuckWhisperer.app" "$MOUNT_POINT/DuckWhisperer.app"
  cp "$STAGING_DIR/Start Here.html" "$MOUNT_POINT/Start Here.html"
  mkdir -p "$MOUNT_POINT/.background"
  cp "$BACKGROUND_PNG" "$MOUNT_POINT/.background/background.png"

  # A real Finder alias carries the /Applications folder icon; a plain symlink renders blank.
  osascript -e "tell application \"Finder\" to make alias file to (POSIX file \"/Applications\") at (POSIX file \"$MOUNT_POINT\")" >/dev/null
  if [[ -e "$MOUNT_POINT/Applications alias" ]]; then
    mv "$MOUNT_POINT/Applications alias" "$MOUNT_POINT/Applications"
  fi

  # Finder won't lazily render the /Applications system icon on a scripted DMG, so stamp it explicitly.
  ICON_SCRIPT="$STAGING_ROOT/set_applications_icon.swift"
  cat > "$ICON_SCRIPT" <<'SWIFTEOF'
import AppKit
let target = CommandLine.arguments.last ?? ""
let icon = NSWorkspace.shared.icon(forFile: "/Applications")
NSWorkspace.shared.setIcon(icon, forFile: target, options: [])
SWIFTEOF
  /usr/bin/swift "$ICON_SCRIPT" "$MOUNT_POINT/Applications"

  echo "Configuring Finder layout..."
  osascript <<EOF >/dev/null
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set sidebar width of container window to 0
        set the bounds of container window to {200, 200, 800, 620}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set text size of viewOptions to 12
        set background picture of viewOptions to file ".background:background.png"
        set position of item "DuckWhisperer.app" of container window to {150, 200}
        set position of item "Applications" of container window to {450, 200}
        set position of item "Start Here.html" of container window to {300, 340}
        update without registering applications
        delay 2
        close
        open
        update without registering applications
        delay 3
        close
    end tell
end tell
EOF

  sync
  sleep 1
  hdiutil detach "$MOUNT_POINT" >/dev/null
  echo "Compressing to read-only DMG..."
  hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
  rm -f "$TEMP_DMG"
  du -h "$DMG_PATH"
  created_packages+=("- $DMG_PATH")
  created_package_paths+=("$DMG_PATH")
fi

write_release_notes "$(printf '%s\n' "${created_packages[@]}")"
cp "$RELEASE_NOTES" "$SPARKLE_RELEASE_NOTES"

if [[ "${GENERATE_SPARKLE_APPCAST:-0}" == "1" ]]; then
  if [[ "${#created_package_paths[@]}" -eq 0 ]]; then
    echo "No package was created for Sparkle appcast generation." >&2
    exit 1
  fi

  sparkle_update_path="${created_package_paths[0]}"
  for package_path in "${created_package_paths[@]}"; do
    if [[ "$package_path" == *.zip ]]; then
      sparkle_update_path="$package_path"
      break
    fi
  done

  mkdir -p "$SPARKLE_ARCHIVE_DIR"
  cp "$sparkle_update_path" "$SPARKLE_ARCHIVE_DIR/$(basename "$sparkle_update_path")"
  cp "$SPARKLE_RELEASE_NOTES" "$SPARKLE_ARCHIVE_DIR/$(basename "${sparkle_update_path%.*}").md"
  "$ROOT_DIR/scripts/generate_sparkle_appcast.sh" "$SPARKLE_ARCHIVE_DIR"
  cp "$SPARKLE_ARCHIVE_DIR/appcast.xml" "$RELEASE_DIR/appcast.xml"
fi

cat <<EOF

Release package created in:
$RELEASE_DIR

Release notes:
$RELEASE_NOTES

Sparkle release notes:
$SPARKLE_RELEASE_NOTES

Sparkle appcast archive dir:
$SPARKLE_ARCHIVE_DIR

Speech models and translator add-ons remain optional and install only after user approval on first launch.
Set BUNDLE_DEFAULT_MODEL=1 to bake the Best Accuracy English model into the app for an offline-first DMG.
Set REQUIRE_SPARKLE_CONFIG=1 GENERATE_SPARKLE_APPCAST=1 for a signed Sparkle appcast release.
EOF
