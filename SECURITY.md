# Security Policy

## Supported Versions

Before `1.0`, BurnBar only supports the latest tagged prerelease and the current `main` branch. Older commits may contain known issues and may not receive fixes.

## Reporting a Vulnerability

We take security bugs seriously. If you discover a security vulnerability, please report it responsibly.

**Please do not file a public GitHub issue for security vulnerabilities.**

Preferred private path:

1. Use GitHub's private vulnerability reporting or a draft security advisory if it is enabled for this repository.
2. If private reporting is not available, contact the maintainer privately through the repository owner profile: https://github.com/Ajnunezg

### What to Include

A good vulnerability report should include:

- Type of vulnerability (e.g., injection, auth bypass, data exposure)
- Full paths of source file(s) related to the vulnerability
- Location of the affected source code (tag/branch/commit or direct path)
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact assessment — how an attacker could exploit this

We do not promise formal SLA response times. Reports are handled on a best-effort basis.

## Security Best Practices for BurnBar Users

- **Secrets**: Routed provider API keys, Hermes/OpenClaw bearer tokens, the controller Telegram bot token, and daemon-managed connector credentials use macOS Keychain with a device-local accessibility class.
- **Local data**: Default storage is local SQLite. Cloud sync (Firebase) is opt-in.
- **Cloud sync scope**: When cloud sync is enabled, BurnBar currently uploads usage rows and in-app BurnBar chat threads for cross-device resume. Conversation metadata and full session-log backup remain separately gated by their own settings.
- **OAuth flows**: Firebase Auth handles Google and Apple sign-in. Verify redirect URIs match `com.burnbar.app`.
- **Extension permissions**: The BurnBar extension requests minimal capabilities. Review workspace trust settings in Cursor/VS Code.
- **Daemon socket**: The local daemon uses a UNIX domain socket. Ensure filesystem permissions restrict access to your user account only.
- **Cursor connector runtime**: The local connector bridge keeps provider API keys in Keychain and writes only Keychain lookup metadata plus a short-lived session token into BurnBar's private support directory while the bridge is active.
- **Optional integrations**: Connector-plane, browser-tooling, and tunnel features expand the network surface area. Enable only the integrations you actually plan to use.

## Known Limitations

- **Cost estimates**: Cost calculations use public pricing lists and do not reflect actual invoices. Do not use for financial reconciliation.
- **Parser heuristics**: Some provider log formats require estimation. The "Exact" vs "Estimated" column in the README indicates confidence level.
- **Factory exact quota**: BurnBar no longer borrows session state from other local apps for Factory exact quota. Use explicit `FACTORY_COOKIE_HEADER` and/or `FACTORY_BEARER_TOKEN` overrides if you want the official API path.
- **Local settings**: Non-secret values such as gateway URLs, chat model overrides, and controller chat IDs still live in app preferences on the same Mac.
- **Third-party tunnels**: When using the Cursor connector with cloud tunnels, review tunnel provider privacy policies.
