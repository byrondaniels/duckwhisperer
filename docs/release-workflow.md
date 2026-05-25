# Plume Release Workflow

This is the packaging path for a non-developer release.

## Build The DMG

```bash
./scripts/package_release.sh
```

The default artifact is:

```text
release/Plume-<version>-<build>.dmg
```

The DMG contains:

- `Plume.app`
- an `Applications` shortcut for drag-and-drop install
- `Start Here.html` with the first-run instructions

To also create a ZIP:

```bash
PACKAGE_FORMAT=both ./scripts/package_release.sh
```

## Optional GitHub Action

A GitHub Actions template lives at `docs/github-actions/package-macos.yml`. If the repository token has GitHub's `workflow` scope, place that file at `.github/workflows/package-macos.yml` to build DMG and ZIP artifacts from `workflow_dispatch` or version tags.

## Sign A Public Build

Local ad-hoc builds work for testing, but a public release should use a Developer ID certificate:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/package_release.sh
```

The script signs `Plume.app` through `scripts/build_app.sh` and writes release notes next to the artifact.

## Notarize A Public DMG

After building with a Developer ID certificate, notarize and staple the DMG:

```bash
NOTARYTOOL_PROFILE=plume-release ./scripts/notarize_release.sh
```

Create that stored Apple profile once with:

```bash
xcrun notarytool store-credentials plume-release --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-password"
```

You can also pass credentials through `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_APP_SPECIFIC_PASSWORD`. The script submits the DMG, waits for the result, staples the ticket, and validates the package with `spctl`.

## What Ships

The release app bundles Best Accuracy English dictation so a new user can install and transcribe without a terminal or first-run model download.

These remain opt-in downloads inside Plume:

- non-English speech models
- local translation packages
- Enhanced Robot local style assets

## Non-Developer Install Test

Before publishing:

1. Run `./scripts/verify.sh`.
2. Run `./scripts/package_release.sh`.
3. For a public build, run `./scripts/notarize_release.sh`.
4. Open the DMG.
5. Drag `Plume.app` to `Applications`.
6. Open Plume from Applications.
7. Open `Finish Setup...`.
8. Grant Microphone and Paste-Back permissions.
9. Open `Try It Here...`, record once, and confirm the text appears.
10. Test paste-back in TextEdit or Notes with the cursor in a text field.
11. Open `Settings -> Export Support Bundle...` and confirm a ZIP is created without transcript history.

## User Customization Checklist

Plume's menu-bar settings cover normal non-dev customization:

- `Writing Mode`: email, notes, bullets, raw dictation, Slack casual, and more
- `Saved Words...`: personal dictionary replacements
- `App Defaults`: per-app model, output, and writing mode
- `Preserve Capitalization`
- `History`: recent local transcripts and time-saved stats
- `Time Saved`: main-menu tracker for the value users get from dictation
- `Settings -> Advanced`: input language, output language, model choice, optional asset downloads, audio ducking, presenter mode, translation, and fun modes
- `Settings -> Export Support Bundle...`: diagnostics for support without transcript history

## Versioning

Update `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist` before a public release. The artifact name and release notes use those values.
