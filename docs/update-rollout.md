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

For appcast signing in CI, pass the private key through Sparkle's tooling using
`--ed-key-file -`, or import it into the build keychain before running
`generate_appcast`.

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

5. Publish the DMG and the generated `release/appcast.xml`.
6. Make sure `appcast.xml` is reachable at `SUFeedURL`.
7. Open an older installed build and use `Settings -> Check For Updates...`.

The release script stages Sparkle update archives in `release/sparkle/` to avoid
duplicate appcast entries when both a DMG and ZIP exist for the same app build.
Sparkle uses the ZIP when one is available; the DMG can still be published for
manual drag-and-drop installs.

## Hosting Options

Cheapest path:

- Host `appcast.xml` on GitHub Pages.
- Host DMGs on GitHub Releases.
- Run `scripts/generate_sparkle_appcast.sh` with `SPARKLE_DOWNLOAD_URL_PREFIX`
  pointing at the release asset URL prefix.

More controlled path:

- Host appcast and DMGs on S3 behind CloudFront.
- Use Terraform for bucket, CloudFront, TLS/domain wiring, cache policy, and
  deploy credentials.

## Notes

Sparkle update archives must be signed with the same Sparkle EdDSA key whose
public half is embedded in the app. Public releases should also use stable
Developer ID signing and notarization so macOS trust, Gatekeeper, and
Accessibility behavior remain predictable.
