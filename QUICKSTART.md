# BurnBar Quick Start Guide

Get up and running with BurnBar in under 2 minutes.

## Prerequisites

- macOS 14 Sonoma or later
- Xcode 16+ command line tools (`xcode-select --install`)

## Installation

### Option 1: Homebrew Cask (recommended, once notarized builds are available)

```bash
brew install --cask Ajnunezg/tap/burnbar
```

### Option 2: Download from GitHub Releases

1. Go to [Releases](https://github.com/Ajnunezg/BurnBar/releases)
2. Download the latest `.dmg`
3. Open the DMG and drag **BurnBar** to **Applications**
4. Launch BurnBar — look for it in your menu bar

### Option 3: Build from Source (one command)

```bash
git clone https://github.com/Ajnunezg/BurnBar.git
cd BurnBar
make install
```

This builds a Release .app and copies it to `/Applications`. Then run:

```bash
open -a BurnBar
```

To uninstall: `make uninstall`

### Option 4: Open in Xcode (for development)

```bash
git clone https://github.com/Ajnunezg/BurnBar.git
cd BurnBar
open BurnBar.xcodeproj
```

Select the **BurnBar** scheme, press **⌘R** to build and run.

### Building the Daemon Separately

```bash
# Build the daemon CLI
swift run --package-path BurnBarDaemon BurnBarCLI -- help

# Run tests
swift test --package-path BurnBarCore
swift test --package-path BurnBarDaemon
./scripts/test-burnbar-app.sh
```

## Running the Editor Extension

```bash
cd extensions/burnbar

# Install dependencies
npm install

# Build the extension
npm run build

# Run tests
npm run test:unit
```

To try the extension locally:
1. Open VS Code or Cursor
2. Open the `extensions/burnbar` folder as an extension project
3. Use your editor's local development / unpacked-extension flow to run or load it
4. There is not currently a published marketplace build or signed VSIX in this repository

## First-Time Setup

### For Usage Tracking Only (No Cloud)

1. Run BurnBar from Xcode
2. The app will automatically detect AI agent session logs in:
   - `~/.claude/projects/`
   - `~/.factory/sessions/`
   - `~/.codex/` (including the local state database and rollout/session files)
3. Watch your token usage appear in the menu bar!

### For Cloud Sync (Optional)

1. Create a [Firebase project](https://console.firebase.google.com)
2. Add a macOS app with bundle ID `com.burnbar.app`
3. Enable Google and/or Apple Sign-In
4. Set up Firestore with the rules from `firestore.rules`
5. Download `GoogleService-Info.plist` → `AgentLens/Resources/GoogleService-Info.plist`
6. Add your **DEVELOPMENT_TEAM** to `project.yml` under the BurnBar target
7. Rebuild

With cloud sync enabled today, BurnBar uploads usage rows and in-app BurnBar chat threads for cross-device resume. Conversation metadata backup and full session-log backup are controlled separately in Settings.

## Project Structure

| Directory | Description |
|-----------|-------------|
| `AgentLens/` | SwiftUI menu bar app |
| `BurnBarCore/` | Shared types and RPC contracts |
| `BurnBarDaemon/` | Local JSON-RPC daemon |
| `extensions/burnbar/` | Cursor/VS Code extension |
| `docs/` | Architecture and design docs |

## Common Tasks

### Run All Tests

```bash
# Swift tests
swift test --package-path BurnBarCore
swift test --package-path BurnBarDaemon
./scripts/test-burnbar-app.sh

# TypeScript tests
cd extensions/burnbar && npm run test:ci
```

### Add a New Provider Parser

1. Create a new file conforming to `LogParser` protocol
2. Register in `UsageAggregator.init()`
3. Add provider colors to `DesignSystem.swift`

### Static Checks

```bash
# Swift practical verification
./scripts/test-burnbar-swift.sh
./scripts/test-burnbar-app.sh
./scripts/test-burnbar-retrieval-evals.sh

# TypeScript
cd extensions/burnbar && npm run lint
```

`swiftlint` is configured for maintainer cleanup, but the current source release is not yet fully SwiftLint-clean. Use the repo-native Swift test/eval scripts above as the practical verification path today.

The authoritative app XCTest target is `BurnBarTests`, and it intentionally compiles only `AgentLensTests.swift` plus `BurnBarSearchIntegrationHarness.swift`. See [AgentLensTests/README.md](AgentLensTests/README.md) for the active-vs-parked policy. Optional real-provider smoke coverage remains opt-in via `BURNBAR_REAL_PROVIDER_SMOKE=1`.

## Troubleshooting

### "BurnBar daemon not found"

Make sure the daemon is built:
```bash
swift build --package-path BurnBarDaemon
```

### "Socket connection refused"

The daemon isn't running. Start it:
```bash
swift run --package-path BurnBarDaemon BurnBarDaemon
```

### Extension not connecting

1. Make sure BurnBar is running
2. Click "Repair Daemon" in the extension's health panel
3. Check the daemon is listening on its socket path

## Getting Help

- **Bug reports:** https://github.com/Ajnunezg/BurnBar/issues
- **Security issues:** See [SECURITY.md](SECURITY.md)
- **Contributing:** See [CONTRIBUTING.md](CONTRIBUTING.md)
- **Support expectations:** See [SUPPORT.md](SUPPORT.md)

## Next Steps

- Read the [Architecture Overview](docs/BURNBAR_RELEASE_ARCHITECTURE.md)
- Check the [Roadmap](docs/ROADMAP.md)
- Explore the [Design System](DESIGN.md)
