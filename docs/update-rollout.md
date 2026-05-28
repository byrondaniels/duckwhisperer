# DuckWhisperer Update Rollout

DuckWhisperer currently uses GitHub Releases as the release channel.

## Implemented Lightweight Flow

The app checks GitHub's latest release endpoint:

```text
https://api.github.com/repos/byrondaniels/duckwhisperer/releases/latest
```

It compares the release tag and DMG build number against the installed bundle's
`CFBundleShortVersionString` and `CFBundleVersion`.

The user flow is:

1. DuckWhisperer performs a quiet update check at launch at most once every 12 hours.
2. If a newer release exists, it shows an update alert once for that release.
3. The user can download the latest DMG or view the release page.
4. Manual checks are available from `Settings -> Check For Updates...`.

This requires no extra infrastructure beyond GitHub Releases. Every release should upload a
DMG named:

```text
DuckWhisperer-<short-version>-<build>.dmg
```

Example:

```text
DuckWhisperer-0.1.1-2.dmg
```

## What This Does Not Do Yet

This does not replace the installed app automatically. The user still downloads the DMG and
drags the app into Applications.

That is intentional for the current lightweight implementation. Replacing a running `.app`
inside `/Applications` safely requires an updater helper, signature validation, relaunch
logic, and careful handling of macOS quarantine and permissions.

## Full Native Auto-Update Path

For the standard macOS "Download, install, relaunch" experience, use Sparkle 2.

Required changes:

- Bundle Sparkle.framework and its updater helper in `DuckWhisperer.app`.
- Add Sparkle keys/settings to `Info.plist`, including the appcast URL.
- Generate and store Sparkle EdDSA signing keys.
- Sign each update archive with Sparkle's signing tool.
- Publish an HTTPS appcast feed that points to the signed DMG or ZIP.
- Keep Developer ID signing and notarization stable across releases.
- Add release automation that builds, signs, notarizes, uploads, and regenerates the appcast.

Infrastructure choices:

- No new infrastructure: host the appcast and DMGs on GitHub Releases or GitHub Pages.
- Optional infrastructure: host the appcast and DMGs on S3 plus CloudFront. Terraform would
  create the bucket, CloudFront distribution, TLS/domain wiring, cache policy, and deployment
  credentials. Do not apply that until the update channel/domain is chosen.

## Release Checklist

1. Bump `CFBundleShortVersionString` and `CFBundleVersion`.
2. Run `./scripts/verify.sh`.
3. Run `./scripts/package_release.sh`.
4. Publish a GitHub release tag that matches the short version, for example `v0.1.1`.
5. Upload the DMG asset.
6. Open an installed older build and use `Settings -> Check For Updates...`.
