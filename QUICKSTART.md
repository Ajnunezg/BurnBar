# BurnBar Quick Start Guide

Get up and running with BurnBar in 5 minutes.

## Prerequisites

- macOS 14 Sonoma or later
- Xcode 16+ (for building)
- Swift 5.10+
- Node.js 18+ and npm (for editor extension development only)

## Installation

### Option 1: Build from Source

```bash
# Clone the repository
git clone https://github.com/Ajnunezg/BurnBar.git
cd BurnBar

# Generate the Xcode project (requires XcodeGen)
brew install xcodegen
xcodegen generate

# Open in Xcode
open BurnBar.xcodeproj
```

### Option 2: Swift Package Manager

```bash
# Build the daemon CLI
swift run --package-path BurnBarDaemon BurnBarCLI -- help

# Run tests
swift test --package-path BurnBarCore
swift test --package-path BurnBarDaemon
```

## Running the App

1. Open `BurnBar.xcodeproj` in Xcode
2. Select the **BurnBar** scheme
3. Press **⌘R** to build and run
4. Look for the BurnBar icon in your menu bar

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

To load the extension:
1. Open VS Code or Cursor
2. Go to Extensions (⇧⌘X)
3. Click the "..." menu → "Install from VSIX" (or load unpacked)
4. Select the `extensions/burnbar` folder

## First-Time Setup

### For Usage Tracking Only (No Cloud)

1. Run BurnBar from Xcode
2. The app will automatically detect AI agent session logs in:
   - `~/.claude/sessions/`
   - `~/.factory/sessions/`
   - `~/.codex/data/`
3. Watch your token usage appear in the menu bar!

### For Cloud Sync (Optional)

1. Create a [Firebase project](https://console.firebase.google.com)
2. Add a macOS app with bundle ID `com.burnbar.app`
3. Enable Google and/or Apple Sign-In
4. Set up Firestore with the rules from `firestore.rules`
5. Download `GoogleService-Info.plist` → `AgentLens/Resources/GoogleService-Info.plist`
6. Add your **DEVELOPMENT_TEAM** to `project.yml` under the BurnBar target
7. Rebuild

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

# TypeScript tests
cd extensions/burnbar && npm run test:ci
```

### Add a New Provider Parser

1. Create a new file conforming to `LogParser` protocol
2. Register in `UsageAggregator.init()`
3. Add provider colors to `DesignSystem.swift`

### Lint and Type Check

```bash
# Swift
swiftlint

# TypeScript
cd extensions/burnbar && npm run lint
```

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

- **Bug reports:** [GitHub Issues](https://github.com/Ajnunezg/BurnBar/issues)
- **Security issues:** See [SECURITY.md](SECURITY.md)
- **Contributing:** See [CONTRIBUTING.md](CONTRIBUTING.md)
- **Support expectations:** See [SUPPORT.md](SUPPORT.md)

## Next Steps

- Read the [Architecture Overview](docs/BURNBAR_RELEASE_ARCHITECTURE.md)
- Check the [Roadmap](docs/ROADMAP.md)
- Explore the [Design System](DESIGN.md)
