<div align="center">
  <img src="AgentLens/Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" width="96" alt="BurnBar" />

  # BurnBar

  > A native macOS app that watches your AI coding agents so you don't have to wonder where all your money went.

  **Status:** Experimental source release (v0.1.0-beta) — best-effort support, feedback welcome.

</div>

If you're the kind of person who has three AI agents running in parallel tabs and only checks the bill at the end of the month, this is for you. BurnBar sits quietly in your menu bar, reads the local session logs your agents leave behind, and gives you a live view of tokens burned and dollars spent across the providers you actually use.

For the paranoid-and-proud crowd: analytics stay **local-first**. No API keys, no account, no cloud — unless you *want* cloud. BurnBar also ships a **Cursor / VS Code extension** that talks to a small **local daemon** so your editor and your meter can be friends.

This repository is safe to inspect and build from source, but it should still be treated as an **experimental** project rather than a polished 1.0 release. Optional cloud sync, tunnels, and editor integration are provided on a best-effort basis.

## Architecture stance

BurnBar is now explicitly **daemon-first** and **local-first**.

- Local SQLite plus daemon-owned local state are canonical.
- Firestore is an optional replication and collaboration plane.
- iCloud mirroring is an optional file-copy plane.
- Neither cloud path replaces local state as the source of truth.

The current architecture canon lives in [BURNBAR_RELEASE_ARCHITECTURE.md](docs/BURNBAR_RELEASE_ARCHITECTURE.md).

**Cursor deep dives** (for humans and agents):

- [BurnBar Mission](docs/MISSION.md)
- [BurnBar Direction](docs/DIRECTION.md)
- [BurnBar Roadmap](docs/ROADMAP.md)
- [BurnBar + Cursor Agent Onboarding](docs/BURNBAR_CURSOR_AGENT_ONBOARDING.md)
- [BurnBar Current Release Architecture](docs/BURNBAR_RELEASE_ARCHITECTURE.md)

---

## What it does

- **Lives in your menu bar** — no Dock icon, no windows stealing focus. Click when you're curious; forget it exists when you're not.
- **Reads local logs directly** — parses session files from Claude Code, Factory/Droid, Codex, Kimi, and friends. Your API keys never leave the providers you already trust; BurnBar just reads crumbs they dropped on disk.
- **Tracks cost and token volume** — today, this week, this month. Flip between "how many dollars" and "how many tokens" like the sophisticated chaos goblin you are.
- **Smart insights** — the InsightEngine notices patterns: spend up 40% vs yesterday, cache hits doing heavy lifting, first date with a shiny new model. Little cards, not a spreadsheet cosplaying as a product.
- **Per-provider breakdown** — see which agent is winning the "most expensive hobby" award and whether it's gaining on yesterday's champion.
- **Daily digest** — optional notification at a time you pick, because future-you deserves a single sentence of truth instead of a billing surprise.
- **Chat panel** — ask questions about *your* usage data inside the dashboard. Meta? A little. Useful? Also a little. Delightful? We think so.
- **Optional cloud sync** — sign in with **Google or Apple** (Firebase under the hood), and your totals can follow you across Macs. Fully opt-in; flip it off anytime and your local world keeps spinning.
- **Optional Cursor connector** — route selected **Z.ai** and **MiniMax** models through a local OpenAI-shaped router plus a tunnel, because Cursor is picky about BYOK targets. BurnBar logs those requests so you know where the bits actually went.
- **Daemon-backed controller runtime** — project registry, questions, followups, missions, scheduled reviews, simulator replay, mission provenance, and auto-takeover now live behind the local daemon instead of a UI-only mirror.
- **Operational tool plane** — BurnBar exposes daemon-owned connector status/actions for GitHub, Slack, Linear, PostHog, Sentry, and Gmail, plus browser tooling status/actions for the system browser and daemon-side fetch/link extraction.

## CLI control plane

BurnBar now ships a local CLI alongside the daemon:

```bash
swift run --package-path BurnBarDaemon BurnBarCLI -- help
```

Current commands:

- `health`
- `controller [projectSlug]`
- `questions [projectSlug]`
- `followups [projectSlug]`
- `missions [projectSlug]`
- `mission-approve <missionID> [note]`
- `simulator-runs [projectSlug]`
- `simulator-replay <runID>`

---

## Local-first retrieval architecture

BurnBar search is now backed by a derived local retrieval substrate. `GRDB/SQLite` remains the interactive authority; Firestore is replication/collaboration infrastructure for shared artifacts, not the serving search path.

### Projection pipeline

```text
ConversationIndexer + ArtifactDiscovery + SharedArtifactSync
                        |
                        v
                 source rows in SQLite
      (conversations + source_artifacts + sync state)
                        |
                        v
                  projection_jobs queue
                        |
                        v
            ProjectionPipelineService.runSweep()
                        |
                        +--> search_documents + search_chunks + FTS
                        +--> chunk_embeddings + embedding_versions
                        +--> retrieval_health (projection/semantic/rebuild)
```

### Retrieval pipeline

```text
SearchService.retrieve(query)
        |
        +--> lexical candidates from search_chunks_fts (always on)
        +--> semantic candidates from vector index (optional)
                ANN -> exact fallback -> exact bounded rerank baseline
        |
        v
 candidate union -> bounded rerank -> source hydration -> RBAC/visibility filters
        |
        v
 chat/session/context consumers
```

### Shared/team collaboration flow

```text
Local shared artifact edit
        |
        v
CloudSyncService merge decision (local vs synced vs remote hash)
        |
        +--> Firestore shared artifact head + revision checks (optimistic concurrency)
        +--> local permission snapshot + audit events
        +--> projection reproject/purge jobs for local search parity
```

### Health, rebuild, and re-embed behavior

- BurnBar materializes typed subsystem health in `retrieval_health` (parser/import, discovery, projection, lexical, semantic, rebuild, collaboration, insight rollups).
- Degraded states surfaced to consumers include: **Index stale**, **Semantic unavailable**, **Rebuild in progress**, and **Cloud/shared unavailable**.
- Rebuild/re-embed are durable queue jobs (`projection_jobs`) with retry/cancel semantics; lexical retrieval remains available when semantic indexing is degraded.

### Test and eval entrypoints

- `scripts/test-burnbar-swift.sh` — Swift package tests (`BurnBarCore`, `BurnBarDaemon`)
- `scripts/test-burnbar-retrieval-evals.sh` — retrieval + authoring replay/golden suites
- `scripts/test-burnbar-release-smoke.sh` — end-to-end release smoke (Swift + retrieval evals + extension tests + daemon health)

Implementation detail and rollout notes live in [`docs/BURNBAR_SEARCH_ARCHITECTURE_SPINE.md`](docs/BURNBAR_SEARCH_ARCHITECTURE_SPINE.md).

---

## Provider support

| Provider | Usage tracking | Source | Confidence | Quota reporting |
|---|---|---|---|---|
| Claude Code | Supported | `~/.claude/projects/*.jsonl` | Exact | Supported via Claude statusline bridge (5-hour / 7-day %) |
| Factory (Droid) | Supported | `~/.factory/sessions/*.jsonl` | Exact | Estimated via plan tier + BurnBar-tracked monthly Factory tokens |
| Codex (OpenAI) | Partial | `~/.codex/state_5.sqlite` + rollout JSONL | Estimated | Supported via the latest local Codex rollout/session rate-limit snapshot |
| Kimi (Moonshot) | Partial | `~/.kimi/sessions/*.jsonl` | Estimated | Unavailable |
| Z.ai | Partial | via Factory sessions | Estimated | Supported via official monitor quota endpoints |
| MiniMax | Partial | via Factory sessions | Estimated | Supported for Token Plan via official remains endpoint |
| Copilot | Planned | — | — | Unavailable |
| Aider | Planned | — | — | Unavailable |
| Cursor connector | Supported (optional) | Cursor BYOK + BurnBar local router | Exact | Unavailable |

**Exact** = the log format actually told us the numbers; we're not guessing.

**Estimated** = we applied math and hope — e.g. Codex may only give totals without an input/output split, so BurnBar shrugs and assumes 50/50. Costs everywhere use **public pricing tables**, not your invoice. Good for trends; bad for tax audits.

Quota reporting is separate from spend history. Codex quota comes from the latest local rollout/session snapshot, Claude Code quota comes from the local statusline bridge, MiniMax and Z.ai use official API responses, and Factory / Droid remaining is an explicit estimate from BurnBar-tracked raw monthly tokens rather than Factory billable tokens.

### Cursor agent provider scope (narrower on purpose)

Routed Cursor traffic is a smaller club than the table above.

- **In:** `Z.ai`, `MiniMax`
- **Out (on purpose):** `Kimi`, `pony-alpha-2`, hidden/internal catalog models, browser tools
- **Public catalog examples for routing:** `glm-5-turbo`, `glm-5`, `minimax-m2.7-highspeed`

The sidebar today is honest about being a **shell**: health, catalog, workspace state, recovery copy — the full run-control red carpet is still rolling out.

---

## BurnBar in Cursor (and VS Code)

The extension is **local-first** and **daemon-backed**. Think of it as a polite sidecar, not a second brain.

You get:

- a BurnBar activity bar home with **Health**, **Runs**, and **Run Detail**
- **Reconnect**, **Refresh**, and **Repair Daemon** when the universe is misaligned
- workspace capability detection (local, remote, read-only, virtual, restricted) so the UI doesn't lie to you
- inline recovery prose for the usual failure modes — socket missing, timeout, protocol mismatch, "did you install the daemon?", etc.

**Restricted workspaces** (Cursor/VS Code untrusted mode):

- **Allowed:** `read_file`, `search_workspace`, health, catalog state, projected run state
- **Gated until trusted:** `apply_patch`, `run_terminal`

**Fast start** (five steps, zero mysticism):

1. Run BurnBar on the same Mac as the editor.
2. Install or repair the daemon from BurnBar.
3. Add Z.ai / MiniMax keys if you want routed models.
4. Install the BurnBar extension from `extensions/burnbar` (build with `npm run build` in that folder, then load the unpacked extension in your editor of choice).
5. Open a folder or workspace, then open the BurnBar sidebar and say hi.

---

## Cursor provider routing (the tunnel plot twist)

BurnBar can wire supported models into Cursor without you hand-editing ghost JSON or running a sketchy proxy you found at 2am.

The play:

- Keys live in the **macOS Keychain** (where keys belong).
- You pick which model IDs Cursor should believe in.
- A local **OpenAI-compatible router** wakes up.
- A **public HTTPS tunnel** appears because Cursor blocks `localhost` and private IPs for BYOK — not our rule, just our problem to solve.
- BurnBar writes Cursor's custom-model BYOK settings for you.
- Routed usage shows up as **`BurnBar Cursor Connector`** so your dashboard and your conscience stay aligned.

**v1 scope:** `Z.ai`, `MiniMax`. **Tunnel flavor:** Cloudflare quick tunnel (bring `cloudflared`).

**Checklist:**

1. Install `cloudflared` (Homebrew is fine; the internet is full of opinions).
2. BurnBar → **Settings → Providers → Connect Cursor**
3. Paste keys, pick models, mash **Connect**
4. Leave BurnBar running while Cursor chats through the connector — it's doing real work under the hood.

---

## Repository map (yes, the folder is still named AgentLens)

The Mac app sources live under **`AgentLens/`** because renaming folders is a personality test Xcode sometimes fails. The product name is **BurnBar**; the bundle is **`com.burnbar.app`**. Roll with it.

| Area | What lives there |
|---|---|
| `AgentLens/` | SwiftUI app: menu bar, dashboard, settings, parsers, GRDB store |
| `BurnBarCore/` | Shared types and RPC contracts for app ↔ daemon |
| `BurnBarDaemon/` | Local JSON-RPC daemon + executable wrapper |
| `extensions/burnbar/` | TypeScript extension for Cursor / VS Code |
| `docs/` | Mission, direction, roadmap, architecture, onboarding, and other words we meant |

---

## Requirements

- macOS 14 Sonoma or later
- Xcode 16+
- Swift 5.10
- Node + npm (only if you're hacking the editor extension)

---

## Build (Mac app)

```bash
git clone <repository-url>
cd BurnBar
open BurnBar.xcodeproj
```

Hit **⌘R**. The app shows up in your menu bar like a well-behaved utility.

**xcodegen** fans:

```bash
brew install xcodegen
xcodegen generate
open BurnBar.xcodeproj
```

`LSUIElement` means: no Dock icon, no dramatic launch window — popover first, dashboard when you ask for it.

**Optional:** add your Apple **DEVELOPMENT_TEAM** in `project.yml` under the BurnBar target if Keychain groups (Firebase / Google Sign-In) make Xcode grumpy about signing.

---

## Build (editor extension)

```bash
cd extensions/burnbar
npm install
npm run build
```

Load the `extensions/burnbar` folder as an unpacked extension in Cursor or VS Code.

**Tests** (for the statistically responsible):

```bash
cd extensions/burnbar
npm run test:ci   # unit + replay + extension-host
```

---

## Cloud sync (optional)

BurnBar is a happy offline hermit by default. Cloud sync is for people who use more than one Mac and would like their totals to agree with each other.

**Pieces:**

- **Primary store:** GRDB + SQLite — fast, local, yours
- **Sync store:** Firestore under `users/{uid}/` — `usage`, `conversations` (optional metadata backup), `session_logs` (+ `chunks` for full log backup when enabled)
- **Auth:** Firebase Auth — **Google** and/or **Sign in with Apple**
- **Device identity:** random UUID stored in local app defaults and migrated from legacy BurnBar/AgentLens defaults keys
- **iCloud mirror (optional):** copies parsed session log files into your **personal** iCloud Drive folder for the app (`Documents/BurnBar/SessionMirror/...`). Independent of Firebase; see below.

**Setup:**

1. Create a [Firebase](https://console.firebase.google.com) project and add a **macOS** app with bundle ID `com.burnbar.app`.
2. Enable **Authentication** providers: **Google** and **Apple** (and whatever else you need for your own sanity).
3. Create a Firestore database (production mode) and deploy rules that cover **every** collection the app uses (not only `usage`). If rules allow only `usage`, enabling **Back Up Session History** or full session-log backup yields **“Missing or insufficient permissions.”** Use a single subtree rule (same as [firestore.rules](firestore.rules) in this repo):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

   Paste into **Firebase Console → Firestore → Rules** and publish, or add `firestore.rules` to your Firebase CLI project and run `firebase deploy --only firestore:rules`.

4. Download `GoogleService-Info.plist` → `AgentLens/Resources/GoogleService-Info.plist` (gitignored; never commit). See `AgentLens/Resources/GoogleService-Info.plist.example` for the shape of the thing. In Xcode, use **File → Add Files to "BurnBar"…**, select that plist, and check the **BurnBar** target so it is copied into the app bundle.
5. Configure the **Google Sign-In** URL scheme / OAuth client as Firebase/Google Cloud demand (the app ships `BurnBar-Info.plist` entries for the bundled client; yours will differ in a fork).
6. `xcodegen generate` and rebuild.

**Privacy:** synced payloads can include **project directory names** and **model names** from sessions. You can disable sync in **Settings → Account** without sacrificing local history.

### iCloud session file mirror (optional)

Use this when you want session logs in **your** Apple ID’s iCloud storage instead of (or in addition to) Firestore metadata.

- **Where:** After each successful refresh, BurnBar incrementally copies files from each supported provider’s configured log path into the app’s iCloud container: `Documents/BurnBar/SessionMirror/<provider>/…` (same layout as on disk under that root).
- **UI:** **Settings → Account → iCloud session files** — toggle, status, **Set up guide** (iCloud sign-in check, privacy notes, size estimate, **Reveal in Finder**, **Mirror now**, and advanced Terminal examples for symlink-based relocation).
- **Apple Developer:** Enable **iCloud** for the macOS app ID `com.burnbar.app` with **iCloud Documents** and container `iCloud.com.burnbar.app`, matching [AgentLens/Resources/BurnBar.entitlements](AgentLens/Resources/BurnBar.entitlements).
- **Privacy:** mirrored files can contain paths, prompts, and code snippets. They are **not** uploaded to BurnBar-operated Firebase storage by this feature (they sync through Apple’s iCloud like any other document).
- **Conflicts:** editing the same mirrored file on two Macs can produce iCloud “conflict” copies; BurnBar does not merge those automatically.
- **“Missing or insufficient permissions”:** if this appears during **Firestore** sync or dashboard refresh, update your Firestore security rules for the signed-in user. If it appears only when **mirroring to iCloud**, the Mac build usually needs the **iCloud Documents** capability and matching **provisioning profile** for container `iCloud.com.burnbar.app` (see Apple Developer → Identifiers → your App ID).

---

## Limitations (we're not going to surprise you)

- **Costs are estimates** from public price lists, not your accounting software. Great for vibes and trends; don't use them to fight finance.
- **Heuristics happen** wherever logs are shy about splits. Z.ai / MiniMax in analytics often arrive via Factory session fingerprints — clever, not clairvoyant.
- **Menu bar first** — no always-on main window by default. That's a feature for people who already have seventeen windows.
- **Cloud window:** uploaded totals emphasize roughly the **last 90 days**; ancient history stays local, like your old Xcode archives.

---

## Contributing

[CONTRIBUTING.md](CONTRIBUTING.md) is the tour guide: folder layout, how to teach BurnBar a new parser, `DesignSystem` discipline, and how to click "refresh" like a pro.

**TL;DR for parsers:** conform to `LogParser`, stay `Sendable`, return `[]` when folders ghost you — never throw a tantrum on missing files.

**Design tokens:** [DESIGN.md](DESIGN.md) — adaptive colors, SF Pro Rounded, and the botanical cream agenda.

**Where we're headed:** [docs/ROADMAP.md](docs/ROADMAP.md).

## Support

Support expectations live in [SUPPORT.md](SUPPORT.md).

---

## Security

### App Sandbox

BurnBar intentionally runs **without macOS App Sandbox** (`com.apple.security.app-sandbox = false`). This is required because:

1. **Log file access**: The app monitors AI agent usage by reading log files from directories like `~/.claude/sessions/`, `~/.codex/data/`, and `~/Library/Application Support/Cursor/` — none of which are accessible within a sandboxed app container.

2. **Daemon architecture**: The BurnBarDaemon runs as a separate process that requires full filesystem access to scan and index conversation data across multiple locations.

3. **Firebase Auth + Keychain**: Firebase Authentication requires Keychain access which works more reliably without sandbox restrictions.

4. **iCloud integration**: Session log mirroring to iCloud requires broader file system access than sandboxed apps can request.

**Security implications**: Without sandboxing, if BurnBar is compromised, the attacker has access to the user's home directory. However:

- API keys are stored in the macOS Keychain (not plaintext)
- Network access is primarily to configured providers and optional user-enabled integrations; review connector, browser-tooling, and tunnel settings before enabling them
- The app does not execute untrusted code

### Credential Storage

API keys and authentication tokens are stored in the macOS Keychain using `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. See `AgentLens/Services/CursorConnector/KeychainStore.swift` for implementation details.

### Reporting Vulnerabilities

See [SECURITY.md](SECURITY.md) for our vulnerability disclosure policy.

---

## License

Licensed under the MIT License. See [LICENSE](LICENSE) file for details.

Third-party asset and branding notes live in [THIRD_PARTY.md](THIRD_PARTY.md).
