# DuckWhisperer Release Workflow

This is the packaging path for a non-developer release.

## Build The DMG

```bash
./scripts/package_release.sh
```

The default artifact is:

```text
release/DuckWhisperer-<version>-<build>.dmg
```

The DMG contains:

- `DuckWhisperer.app`
- an `Applications` shortcut for drag-and-drop install
- `Start Here.html` with the first-run instructions

To also create a ZIP:

```bash
PACKAGE_FORMAT=both ./scripts/package_release.sh
```

## GitHub Free-Tier Update Publishing

The checked-in workflow at `.github/workflows/publish-sparkle.yml` builds the
Sparkle ZIP update, signs the appcast, and deploys `release/sparkle/` to GitHub
Pages. That keeps the update feed at the app's default `SUFeedURL`:

```text
https://byrondaniels.github.io/duckwhisperer/appcast.xml
```

One-time GitHub setup:

1. Open `Settings -> Pages`.
2. Set `Build and deployment -> Source` to `GitHub Actions`.
3. Add `SPARKLE_PUBLIC_ED_KEY` and `SPARKLE_PRIVATE_ED_KEY` under
   `Settings -> Secrets and variables -> Actions`.
4. Run the `Publish Sparkle Updates` workflow manually, or push a `v*` tag.

The workflow also uploads the release ZIP and appcast as Actions artifacts for
inspection.

## Sparkle Updates

DuckWhisperer bundles Sparkle 2 for native macOS updates. Run this once on a release machine:

```bash
./scripts/setup_sparkle_keys.sh
```

For public update releases, require Sparkle configuration and generate the signed appcast:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  REQUIRE_SPARKLE_CONFIG=1 \
  GENERATE_SPARKLE_APPCAST=1 \
  ./scripts/package_release.sh
```

The appcast is written to:

```text
release/appcast.xml
```

The Sparkle archive set is kept separately under `release/sparkle/` so the
appcast has only one update archive per bundle version. If both DMG and ZIP are
created, the release script prefers ZIP for Sparkle and leaves the DMG for
manual installs.

Publish that file at the `SUFeedURL` embedded in the app, and publish the DMG
at the URL referenced by the appcast.

To generate and publish the appcast through GitHub Pages instead, use the
`Publish Sparkle Updates` workflow. It sets:

```bash
PACKAGE_FORMAT=zip
REQUIRE_SPARKLE_CONFIG=1
GENERATE_SPARKLE_APPCAST=1
```

and points the appcast archive URLs at GitHub Pages.

## Sign A Public Build

Local ad-hoc builds work for testing, but a public release should use a Developer ID certificate:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/package_release.sh
```

The script signs `DuckWhisperer.app` through `scripts/build_app.sh` and writes release notes next to the artifact.

## Notarize A Public DMG

After building with a Developer ID certificate, notarize and staple the DMG:

```bash
NOTARYTOOL_PROFILE=duckwhisperer-release ./scripts/notarize_release.sh
```

Create that stored Apple profile once with:

```bash
xcrun notarytool store-credentials duckwhisperer-release --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-password"
```

You can also pass credentials through `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_APP_SPECIFIC_PASSWORD`. The script submits the DMG, waits for the result, staples the ticket, and validates the package with `spctl`.

## What Ships

The release app is intentionally small. It does not bundle a speech model by
default; the default English speech model downloads on first launch after the
user approves it. Use `BUNDLE_DEFAULT_MODEL=1` only when you want a larger
offline-first package.

These remain opt-in downloads inside DuckWhisperer:

- non-English speech models
- local translation packages
- Enhanced Robot local style assets

## Non-Developer Install Test

Before publishing:

1. Run `./scripts/verify.sh`.
2. Run `./scripts/package_release.sh`.
3. For a public build, run `./scripts/notarize_release.sh`.
4. Open the DMG.
5. Drag `DuckWhisperer.app` to `Applications`.
6. Open DuckWhisperer from Applications.
7. Open `Finish Setup...`.
8. Grant Microphone and Paste-Back permissions.
9. Open `Try It Here...`, record once, and confirm the text appears.
10. Test paste-back in TextEdit or Notes with the cursor in a text field.
11. Open `Settings -> Export Support Bundle...` and confirm a ZIP is created without transcript history.

## User Customization Checklist

DuckWhisperer's menu-bar settings cover normal non-dev customization:

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
