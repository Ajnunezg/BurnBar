# OpenBurnBar Current Release Architecture

## Canonical Stance

OpenBurnBar is now a daemon-first, local-first product.

The canonical authorities are:

- local SQLite in the app for usage, conversations, retrieval, and shared-artifact projections
- daemon-owned local files for provider routing, controller state, connector/browser config, and run/runtime state

Cloud systems are not canonical:

- Firestore is an optional replication and collaboration plane
- iCloud mirroring is an optional file-copy plane
- neither replaces local SQLite or daemon state as the source of truth

## What Ships Now

OpenBurnBar currently ships four coordinated control surfaces:

- the native macOS app: dashboard, menu bar, Hermes/chat, session logs, settings, controller workbench
- the local daemon: provider routing, mission control, notifications, simulator/replay, connector plane, browser plane
- the Cursor / VS Code extension shell: daemon health, projected run state, workspace trust gating, repair/reconnect flows
- the local CLI: `OpenBurnBarCLI` entrypoints for daemon health, controller status, questions, followups, mission approval, and simulator replay

### Support tiers

| Tier | What it covers |
|------|----------------|
| **Core** | The four surfaces above plus shared `OpenBurnBarCore` contracts; local SQLite + daemon-owned files remain canonical. |
| **Experimental** | Optional Firestore replication, iCloud file mirroring, Cursor connector + tunnel — opt-in and best-effort. |
| **Adjacent tooling** | Repo helper at `tools/openburnbar-mcp/` (read-only MCP bridge to local SQLite) — optional for developers, not part of the runtime spine. |
| **Parked tests** | `AgentLensTests/Parked/` — kept in-repo for future re-enablement, but intentionally excluded from `OpenBurnBarTests`; see `AgentLensTests/README.md`. |

## Boundary Summary

```text
Native OpenBurnBar app
  -> local SQLite + retrieval projections
  -> menu/dashboard/Hermes/session-log/operator UI
  -> daemon RPC client

Local OpenBurnBar daemon
  -> provider routing + run state machine
  -> controller/project/question/followup/mission runtime
  -> simulator/replay + scheduled review automation
  -> connector plane (GitHub/Slack/Linear/PostHog/Sentry/Gmail)
  -> browser plane (system browser + daemon fetcher + detected engines)
  -> local CLI/control-plane entrypoints

Optional cloud planes
  -> Firestore replication/collaboration for opted-in data
  -> iCloud file mirroring for opted-in session copies
```

## State Ownership

### Local SQLite

Owned by the app:

- usage history
- conversations/session logs
- retrieval projections and health
- shared-artifact local cache and sync state
- mirrored controller runtime cache for graceful degradation

### Daemon Support Directory

Owned by the daemon:

- provider config
- usage ledger
- run journal and checkpoints
- controller events and projections
- connector plane config
- browser tooling config

### Keychain

Owned locally on-device:

- routed provider API keys
- controller Telegram token
- connector credentials for the external tool plane

## Mission-Control Runtime

OpenBurnBar mission control is now a real runtime, not a projected shell.

It includes:

- real controller ingestion from OpenBurnBar activity
- durable project registry and review schedules
- question/followup workflow with notifications and deep links
- mission packet dispatch linked to real daemon-managed runs
- mission result provenance from run state and usage ledger
- auto-takeover state/history for eligible failed or stalled work

## Operational Tool Plane

### Connectors

The daemon exposes a durable connector plane for:

- GitHub
- Slack
- Linear
- PostHog
- Sentry
- Gmail

Current supported daemon actions:

- connector configuration/status
- local keychain-backed credential storage
- connection test/sample request per connector

### Browser Tooling

The daemon exposes a browser plane with:

- system-browser launch support
- daemon-side fetch/document/link extraction
- status detection for Playwright and Lightpanda installations

Current intentional limitation:

- Playwright and Lightpanda are surfaced as setup/status engines, but direct daemon actions currently run through the daemon fetcher and system browser rather than full headless automation

## Memory-Sync Decision

OpenBurnBar does not adopt a cloud-canonical memory-sync architecture in this release.

Intentional divergence:

- OpenBurnBar remains local-first and daemon-first
- Firestore is optional replication/collaboration infrastructure
- iCloud is optional mirroring infrastructure
- sync conflicts are resolved against the local canonical state, not by promoting cloud to authority

## CLI Surface

The packaged CLI is:

- `swift run --package-path OpenBurnBarDaemon OpenBurnBarCLI -- help`

Current operator commands:

- `health`
- `controller [projectSlug]`
- `questions [projectSlug]`
- `followups [projectSlug]`
- `missions [projectSlug]`
- `mission-approve <missionID> [note]`
- `simulator-runs [projectSlug]`
- `simulator-replay <runID>`

## Trust And Workspace Behavior

Current shipped restricted-mode behavior in the extension:

- available: `read_file`, `search_workspace`, daemon health, catalog state, projected run state
- gated: `apply_patch`, `run_terminal`

Other workspace limits:

- no workspace open: no workspace tools
- read-only workspace: no edit application
- virtual workspace: no terminal execution
- remote workspace: companion runs on the workspace host when available

## Test Entrypoints

- `swift test --package-path OpenBurnBarCore`
- `swift test --package-path OpenBurnBarDaemon`
- `xcodebuild -scheme OpenBurnBar -project OpenBurnBar.xcodeproj -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO -only-testing:OpenBurnBarTests`

The Xcode target **`OpenBurnBarTests`** (declared in `project.yml`) compiles **only**:

- `AgentLensTests/Active/**`
- `AgentLensTests/Support/**`

Files under `AgentLensTests/Parked/**` remain in the tree as archival reference and do not affect the active test bundle until they are moved back into `Active/` and updated for current APIs. See `AgentLensTests/README.md` and `CONTRIBUTING.md` for the active vs parked policy.
