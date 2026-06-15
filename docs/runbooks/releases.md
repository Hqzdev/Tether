# Release Runbook

Releases are created by pushing a version tag. The release workflow builds a DMG
and publishes it as a GitHub Release asset.

## Release Checklist

1. Confirm `main` is green in GitHub Actions.
2. Choose the next semantic version tag, for example `v0.1.0`.
3. Create and push the tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

4. Open GitHub Actions and watch the `Release` workflow.
5. After it finishes, open GitHub Releases and confirm `Tether.dmg` is attached.

## What The Release Builds

The release job runs:

```bash
./scripts/package-dmg.sh
```

That script:
- Builds the Rust proxy helper with `cargo build --release`.
- Builds the macOS app with `xcodebuild` using the `Tether` scheme.
- Copies `tether-proxy` into `Tether.app/Contents/Helpers`.
- Performs ad-hoc signing.
- Creates `dist/Tether.dmg`.
- Copies the DMG to `web/public/downloads/Tether.dmg` for the website download
  path.

## Failure Handling

If the workflow fails, fix the failing build or packaging step on `main`, then
move the tag to the fixed commit:

```bash
git tag -f v0.1.0
git push origin -f v0.1.0
```

If a bad release was published, delete the GitHub Release in the UI and push a
fixed tag after CI is green.

## Signing Note

The current package script uses ad-hoc signing. For a smoother public install
experience, replace that with Developer ID signing and notarization before a
wide external release.
