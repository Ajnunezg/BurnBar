# macOS release checklist (drag-to-Applications)

This is a manual maintainer checklist for future public releases. It does not imply that notarized binaries are currently published.

BurnBar ships as a Developer ID–signed app with the `BurnBarDaemon` helper embedded under `Contents/Helpers/` (see `BurnBarDaemonBinaryResolver`).

## Build

1. Archive in Xcode (Product → Archive) using the **Release** configuration.
2. Export a **Developer ID** build for distribution.

## Signing & notarization

1. Enable **Hardened Runtime** on the app and helper targets (Release).
2. Sign all nested code (app + `Contents/Helpers/BurnBarDaemon`).
3. Submit to Apple **notarization** and **staple** the ticket to the `.app` / `.dmg` / `.zip`.
4. Verify Gatekeeper: `spctl --assess --verbose /path/to/BurnBar.app`

## Smoke tests after install

1. Launch from **Downloads** (translocated) and from **`/Applications`** after drag-install.
2. Open **Settings → Chat Backends** and confirm gateway URLs/tokens if using Hermes/OpenClaw.
3. Install the per-user daemon from in-app controls and confirm the binary resolves from `Contents/Helpers/BurnBarDaemon`.

## References

- [Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Packaging for distribution](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)
- [Bundle layout](https://developer.apple.com/documentation/bundleresources/placing-content-in-a-bundle)
