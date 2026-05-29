# DuckWhisperer Update Rollout

DuckWhisperer now uses Sparkle 2 for native macOS updates.

## Implemented Flow

The app bundles `Sparkle.framework` and creates an `SPUStandardUpdaterController`
when both Sparkle plist values are present in the built app:

- `SUFeedURL`
- `SUPublicEDKey`

The default feed URL injected by `scripts/build_app.sh` is:

```text
https://byrondaniels.github.io/duckwhisperer/appcast.xml
```

Users get Sparkle's normal update flow:

1. Sparkle checks the appcast on its own schedule.
2. If a signed update is available, Sparkle prompts the user.
3. The user can download, install, and relaunch from Sparkle's UI.
4. Manual checks are available from `Settings -> Check For Updates...`.

If `SUPublicEDKey` is missing, DuckWhisperer disables the Sparkle controller and
the menu item is shown as unavailable. This prevents a local/dev build from
pretending it can verify production updates.

## One-Time Sparkle Setup

Create the Sparkle EdDSA signing key on a release machine:

```bash
./scripts/setup_sparkle_keys.sh
```

This stores the private key in the macOS Keychain and writes the public key to:

```text
.sparkle-public-ed-key
```

The public key is not secret, but the local file is ignored so release machines
and CI can choose their own key management. CI can pass the public key as:

```bash
SPARKLE_PUBLIC_ED_KEY="..." ./scripts/package_release.sh
```

For appcast signing in CI, pass the private key through the
`SPARKLE_PRIVATE_ED_KEY` environment variable. The appcast script streams that
secret into Sparkle's `generate_appcast --ed-key-file -` path so GitHub Actions
does not need your local Keychain.

Export the private key from the release machine when you are ready to configure
CI:

```bash
vendor/Sparkle/bin/generate_keys --account duckwhisperer -x .sparkle-private-ed-key
```

Store the file contents as a GitHub Actions secret named
`SPARKLE_PRIVATE_ED_KEY`, then delete the exported file. Do not commit it.

Store the public key as a GitHub Actions secret named `SPARKLE_PUBLIC_ED_KEY`.
The current release public key is:

```text
vt0SDGGts8p9uzCJQRz9gtnXzT5K+a5KSiTfmd/KCco=
```

## GitHub Free-Tier Publishing

The simplest hosted updater path is now checked in at:

```text
.github/workflows/publish-sparkle.yml
```

It stays on GitHub's free public-repo path:

1. GitHub Actions builds a ZIP update archive and signed Sparkle appcast.
2. GitHub Pages deploys the static contents of `release/sparkle/`.
3. Sparkle reads the appcast from:

```text
https://byrondaniels.github.io/duckwhisperer/appcast.xml
```

One-time repository setup:

1. In GitHub, open `Settings -> Pages`.
2. Set `Build and deployment -> Source` to `GitHub Actions`.
3. Add repository secrets:
   - `SPARKLE_PUBLIC_ED_KEY`
   - `SPARKLE_PRIVATE_ED_KEY`
4. Run `Publish Sparkle Updates` manually from the Actions tab, or push a
   version tag such as `v0.1.3`.

No appcast server, cron box, Terraform, or custom domain is required for this
path. GitHub Pages serves `appcast.xml`, the update ZIP, and the release notes
from one static deployment.

## Release Checklist

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist`.
2. Run `./scripts/verify.sh`.
3. Build a signed release package:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  REQUIRE_SPARKLE_CONFIG=1 \
  GENERATE_SPARKLE_APPCAST=1 \
  ./scripts/package_release.sh
```

4. Notarize the DMG:

```bash
NOTARYTOOL_PROFILE=duckwhisperer-release ./scripts/notarize_release.sh
```

5. Publish the DMG for manual installs.
6. Run the `Publish Sparkle Updates` GitHub Action, or publish
   `release/sparkle/` yourself so `appcast.xml` is reachable at `SUFeedURL`.
7. Open an older installed build and use `Settings -> Check For Updates...`.

The release script stages Sparkle update archives in `release/sparkle/` to avoid
duplicate appcast entries when both a DMG and ZIP exist for the same app build.
Sparkle uses the ZIP when one is available; the DMG can still be published for
manual drag-and-drop installs.

## Hosting Options

Cheapest path:

- Use the checked-in GitHub Actions workflow.
- Serve Sparkle update files from GitHub Pages.
- Attach the DMG to GitHub Releases for manual installers.

More controlled path:

- Host appcast and DMGs on S3 behind CloudFront.
- Use Terraform for bucket, CloudFront, TLS/domain wiring, cache policy, and
  deploy credentials.

## Notes

Sparkle update archives must be signed with the same Sparkle EdDSA key whose
public half is embedded in the app. Public releases should also use stable
Developer ID signing and notarization so macOS trust, Gatekeeper, and
Accessibility behavior remain predictable.
