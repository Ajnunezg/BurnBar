# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.x     | :white_check_mark: |

All versions receive security updates. Users are encouraged to run the latest available release.

## Reporting a Vulnerability

We take security bugs seriously. If you discover a security vulnerability, please report it responsibly.

**Please do not file a public GitHub issue for security vulnerabilities.**

Instead, report it via one of the following:

1. **GitHub Security Advisories** (preferred):
   Navigate to this repository's **Security** tab → **Advisories** → **Report a vulnerability**.

2. **Email**:
   Send details to the repository maintainers.

### What to Include

A good vulnerability report should include:

- Type of vulnerability (e.g., injection, auth bypass, data exposure)
- Full paths of source file(s) related to the vulnerability
- Location of the affected source code (tag/branch/commit or direct path)
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact assessment — how an attacker could exploit this

### Response Timeline

- **Acknowledgement**: Within 48 hours of report receipt
- **Initial assessment**: Within 7 days
- **Remediation plan**: Within 30 days (for confirmed issues)
- **Disclosure**: Coordinated with reporter before public release

## Security Best Practices for BurnBar Users

- **API keys**: Stored in macOS Keychain. Never hardcode or share keys.
- **Local data**: Default storage is local SQLite. Cloud sync (Firebase) is opt-in.
- **OAuth flows**: Firebase Auth handles Google and Apple sign-in. Verify redirect URIs match `com.burnbar.app`.
- **Extension permissions**: The BurnBar extension requests minimal capabilities. Review workspace trust settings in Cursor/VS Code.
- **Daemon socket**: The local daemon uses a UNIX domain socket. Ensure filesystem permissions restrict access to your user account only.

## Known Limitations

- **Cost estimates**: Cost calculations use public pricing lists and do not reflect actual invoices. Do not use for financial reconciliation.
- **Parser heuristics**: Some provider log formats require estimation. The "Exact" vs "Estimated" column in the README indicates confidence level.
- **Third-party tunnels**: When using the Cursor connector with cloud tunnels, review tunnel provider privacy policies.
