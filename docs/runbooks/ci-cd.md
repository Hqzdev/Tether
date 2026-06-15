# CI/CD Runbook

This repository uses GitHub Actions for mechanical quality gates and tag-driven
DMG publication.

## Workflows

### CI

File: `.github/workflows/ci.yml`

Triggers:
- Pushes to `main`.
- Pull requests.

Jobs:
- `file-size` enforces the 200-line Rust/Swift source-file rule with
  `scripts/check-file-size.sh`.
- `proxy-smoke` runs `scripts/smoke-e2e.sh` against the Rust proxy API and a
  temporary SQLite database.
- `rust-quality` runs `cargo fmt --check`, `cargo clippy --workspace
  --all-targets -- -D warnings`, `cargo test --workspace`, and `cargo doc
  --workspace --no-deps` with `RUSTDOCFLAGS=-D warnings`.
- `macos-app` builds the Swift package, builds the Xcode app, builds DocC with
  `xcodebuild docbuild`, installs SwiftLint, and runs `swiftlint lint --strict`.

CI is the merge gate for Phases 5-6 of the modular-monolith migration: the app,
proxy, docs, and style conventions must stay green together.

### Release

File: `.github/workflows/release.yml`

Trigger:
- Push a tag matching `v*`, for example `v0.1.0`.

The release workflow:
1. Checks out the repository on `macos-latest`.
2. Installs the stable Rust toolchain.
3. Builds the proxy helper and macOS app through `scripts/package-dmg.sh`.
4. Uploads `dist/Tether.dmg` to a GitHub Release with generated release notes.

`GITHUB_TOKEN` is provided by GitHub Actions automatically. The workflow grants
`contents: write` so `softprops/action-gh-release` can create releases and
upload the DMG asset.

## Autodeploy Model

There is no always-on production service to deploy. Tether is a local-first
desktop app, so "autodeploy" means automatic publication of a signed build
artifact to GitHub Releases when a version tag is pushed.

The package script also copies the DMG into `web/public/downloads/Tether.dmg`
for the website download path during local packaging. The release workflow's
source of truth is still the GitHub Release asset at `dist/Tether.dmg`.

## Local Preflight

Before pushing a release tag, run:

```bash
scripts/check-file-size.sh
cd proxy && cargo fmt --check && cargo clippy --workspace --all-targets -- -D warnings
cd ..
xcodebuild -project ui/Tether.xcodeproj -scheme Tether -configuration Debug -destination 'generic/platform=macOS' -derivedDataPath /tmp/TetherDerivedData build CODE_SIGNING_ALLOWED=NO
./scripts/package-dmg.sh
```

Run `scripts/smoke-e2e.sh` when proxy behavior changed.
