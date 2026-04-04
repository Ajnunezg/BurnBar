# macOS release checklist (drag-to-Applications)

This is a manual maintainer checklist for **future** packaged macOS releases. It does not imply that notarized binaries are currently published.

Current public release model:

- build OpenBurnBar from source
- treat this checklist as maintainer prep for a later binary release
- do not assume a notarized app, Homebrew formula, marketplace extension, daemon tarball, or other packaged artifact exists yet
- the tagged-release GitHub Actions workflow currently drafts a **source-only** release page and does not attach consumer-ready binaries

OpenBurnBar ships as a Developer ID–signed app with the `OpenBurnBarDaemon` helper embedded under `Contents/Helpers/` (see `OpenBurnBarDaemonBinaryResolver`).

## Build

1. Archive in Xcode (Product → Archive) using the **Release** configuration.
2. Export a **Developer ID** build for distribution.

## Signing & notarization

1. Enable **Hardened Runtime** on the app and helper targets (Release).
2. Sign all nested code (app + `Contents/Helpers/OpenBurnBarDaemon`).
3. Submit to Apple **notarization** and **staple** the ticket to the `.app` / `.dmg` / `.zip`.
4. Verify Gatekeeper: `spctl --assess --verbose /path/to/OpenBurnBar.app`

## Smoke tests after install

1. Launch from **Downloads** (translocated) and from **`/Applications`** after drag-install.
2. Open **Settings → Chat Backends** and confirm gateway URLs/tokens if using Hermes/OpenClaw.
3. Install the per-user daemon from in-app controls and confirm the binary resolves from `Contents/Helpers/OpenBurnBarDaemon`.

## References

- [Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Packaging for distribution](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)
- [Bundle layout](https://developer.apple.com/documentation/bundleresources/placing-content-in-a-bundle)
