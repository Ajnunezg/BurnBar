# Plan 05 — BurnBarDist Mission-Control Parity

## Goal

Finish the remaining BurnBarDist parity work in BurnBar without regressing the
native macOS product that now exists.

This plan assumes:

- BurnBar stays the real product repo.
- BurnBarDist is a spec/reference repo only.
- The daemon remains the source of truth.
- AgentLens remains a native macOS client of daemon-owned runtime state.
- Shared contracts stay in `BurnBarCore`.

Execution prompts:

- [BURNBARDIST_PARITY_PROMPT_PACK.md](../BURNBARDIST_PARITY_PROMPT_PACK.md)

## What Is Already Done

Shipped in BurnBar already:

- native operating-layer cards and shared state across dashboard, menu bar, Hermes, session logs, onboarding, and settings
- daemon-owned controller summary / projects / questions / followups / missions / simulator / replay RPC surface
- local persistent controller journal + projection store
- mission approval and direction override
- Telegram transport, local notification delivery, and EventKit calendar writes

That means the remaining parity work is no longer about surface polish. It is
about deeper runtime behavior, automation, and architecture.

## Remaining Parity Gaps

### 1. Real controller ingestion

The controller exists, but it still is not being populated automatically from
the real BurnBar scan/index/chat/runtime pipeline.

Reference:

- `BurnBarDist/src/openburnbar/mission_control/gstack_control.py`
- `BurnBarDist/src/openburnbar/mission_control/shared_summary.py`
- `BurnBarDist/src/openburnbar/mission_control/conversation_home.py`

BurnBar targets:

- `BurnBarDaemon/Sources/BurnBarDaemon/BurnBarMissionControlService.swift`
- `BurnBarDaemon/Sources/BurnBarDaemon/BurnBarRunService.swift`
- `AgentLens/Services/ProjectionPipelineService.swift`
- `AgentLens/Services/CloudSyncService.swift`
- `AgentLens/Services/BurnBarOperatingLayer.swift`

### 2. Project registry + scheduled runs

BurnBarDist has a `projects.json`-style registry and scheduled daily/weekly
review automation. BurnBar still lacks that full scheduler/registry model.

Reference:

- `BurnBarDist/src/openburnbar/mission_control/gstack_control.py`

BurnBar targets:

- `BurnBarCore/Sources/BurnBarCore/BurnBarMissionControlContracts.swift`
- `BurnBarDaemon/Sources/BurnBarDaemon/BurnBarMissionControlService.swift`
- `AgentLens/Views/Dashboard/ProjectsView.swift`
- `AgentLens/Views/Settings/SettingsView.swift`

### 3. Real review-run launching

BurnBar Telegram/UI controller actions can mutate review state, but they do not
yet launch the same kind of real review workflow BurnBarDist can launch.

Reference:

- `BurnBarDist/src/openburnbar/mission_control/notifications.py`
- `BurnBarDist/src/openburnbar/mission_control/gstack_control.py`

BurnBar targets:

- `BurnBarDaemon/Sources/BurnBarDaemon/BurnBarMissionControlService.swift`
- `BurnBarDaemon/Sources/BurnBarDaemon/BurnBarRunService.swift`
- `AgentLens/Views/Dashboard/DashboardView.swift`

### 4. Richer question workflow

BurnBarDist’s pending-question system still has richer semantics:

- stage labels
- option sets
- question-tracker/deep-link flows
- dedicated new-question notifications

Reference:

- `BurnBarDist/src/openburnbar/mission_control/gstack_control.py`
- `BurnBarDist/src/openburnbar/mission_control/notifications.py`

BurnBar targets:

- `BurnBarCore/Sources/BurnBarCore/BurnBarMissionControlContracts.swift`
- `AgentLens/Views/SessionLogs/SessionLogsView.swift`
- `AgentLens/Views/Dashboard/DashboardView.swift`
- `AgentLens/Services/BurnBarOperatingLayer.swift`

### 5. Auto-takeover

BurnBarDist has a full auto-takeover state/history/execution model for stuck
sessions. BurnBar does not yet.

Reference:

- `BurnBarDist/src/openburnbar/mission_control/gstack_control.py`

BurnBar targets:

- `BurnBarDaemon/Sources/BurnBarDaemon/BurnBarMissionControlService.swift`
- `AgentLens/Services/BurnBarOperatingLayer.swift`
- `AgentLens/Views/SessionLogs/SessionLogsView.swift`

### 6. Mission executor integration

BurnBar stores missions, packets, results, and burn, but they are still not
the real driver of worker execution.

Reference:

- `BurnBarDist/src/openburnbar/mission_control/missions.py`
- `BurnBarDist/src/openburnbar/mission_control/subagents.py`
- `BurnBarDist/src/openburnbar/mission_control/simulator.py`

BurnBar targets:

- `BurnBarDaemon/Sources/BurnBarDaemon/BurnBarMissionControlService.swift`
- `BurnBarDaemon/Sources/BurnBarDaemon/BurnBarRunService.swift`
- `BurnBarDaemon/Sources/BurnBarDaemon/BurnBarDaemonServer.swift`

### 7. External connector + browser tool plane

BurnBarDist still has a wider operational tool surface:

- GitHub
- Slack
- Linear
- PostHog
- Sentry
- Gmail
- browser tooling

Reference:

- `BurnBarDist/src/openburnbar/connectors.py`
- `BurnBarDist/src/openburnbar/mission_control/tools.py`
- `BurnBarDist/src/openburnbar/browser_tools.py`

BurnBar targets:

- `BurnBarCore/Sources/BurnBarCore/BurnBarContracts.swift`
- `BurnBarDaemon/Sources/BurnBarDaemon/BurnBarDaemonServer.swift`
- `BurnBarDaemon/Sources/BurnBarDaemon/BurnBarRunService.swift`
- `AgentLens/Views/Settings/SettingsView.swift`

### 8. Cloud-canonical memory-sync architecture

BurnBarDist’s event-memory thesis still exceeds BurnBar’s implementation.
BurnBar remains local/daemon-first, not cloud-canonical.

Wave 5 decision:

- keep BurnBar local-first and daemon-first
- treat Firestore as optional replication/collaboration infrastructure
- treat iCloud as optional mirroring infrastructure
- document the divergence explicitly instead of leaving memory-sync authority ambiguous

Reference:

- `BurnBarDist/docs/designs/event-memory-and-sync.md`
- `BurnBarDist/docs/designs/execution-blueprint.md`

BurnBar targets:

- `AgentLens/Services/DataStore.swift`
- `AgentLens/Services/CloudSyncService.swift`
- new `memory-sync` layer/service boundary

### 9. CLI/control-plane parity

BurnBarDist still has a stronger CLI/control-plane identity than BurnBar.

Reference:

- `BurnBarDist/README.md`
- `BurnBarDist/ARCHITECTURE.md`

BurnBar targets:

- new CLI target over daemon/controller services

### 10. Docs and architectural canon

BurnBar’s docs still do not fully describe the new daemon-first mission-control
architecture as the official product canon.

Reference:

- `BurnBarDist/ARCHITECTURE.md`
- `BurnBarDist/docs/designs/implementation-checklist.md`

BurnBar targets:

- `docs/BURNBAR_RELEASE_ARCHITECTURE.md`
- `docs/BURNBAR_IMPLEMENTATION_CHECKLIST.md`
- `README.md`

## Execution Order

### Tranche 1 — Make the controller real

1. Real controller ingestion
2. Project registry + schedules
3. Real review-run launching

Why first:

- this turns the existing native UI into a real daemon-backed product instead of
  a mostly mirrored shell
- it unlocks meaningful manual testing and operator trust

### Tranche 2 — Make the workflow deep

4. Richer question workflow
5. Auto-takeover
6. Mission executor integration

Why second:

- this is the biggest BurnBarDist semantic gap after the controller spine
- it upgrades BurnBar from “controller state viewer” to “controller runtime”

### Tranche 3 — Finish the system shape

7. External connector + browser tool plane
8. Cloud-canonical memory-sync architecture
9. CLI/control-plane parity
10. Docs and architectural canon

Why third:

- these are large and cross-cutting
- they are important for full BurnBarDist parity but not required to make the
  new native BurnBar controller feel real day to day

## Parallelization Strategy

This plan can and should be parallelized, but only around a small critical
path. The safe rule is:

- keep shared contracts and daemon/runtime ingestion on the critical path
- split app surfaces, tests, docs, and sidecar runtime features into parallel workstreams
- never let two workers own the same file set in the same wave unless one is
  explicitly the integrator

### Critical Path

These must land in sequence because later work depends on them:

1. controller ingestion shape
2. project registry contracts
3. real review-run launching contracts
4. mission executor integration contracts
5. cloud-memory-sync decision

If these are wrong, parallel UI or docs work will have to be redone.

### Safe Parallel Workstreams

#### Workstream A — Contracts

Ownership:

- `BurnBarCore/Sources/BurnBarCore/BurnBarMissionControlContracts.swift`
- `BurnBarCore/Sources/BurnBarCore/BurnBarContracts.swift`
- related BurnBarCore tests

Parallelizable when:

- scope and envelope shape are agreed for the tranche

Blocks:

- daemon runtime implementation
- some app integration work

#### Workstream B — Daemon Runtime

Ownership:

- `BurnBarDaemon/Sources/BurnBarDaemon/BurnBarMissionControlService.swift`
- `BurnBarDaemon/Sources/BurnBarDaemon/BurnBarRunService.swift`
- `BurnBarDaemon/Sources/BurnBarDaemon/BurnBarDaemonServer.swift`
- daemon tests

Parallelizable when:

- contracts are stable enough for the tranche

Can run in parallel with:

- app UI work that only consumes existing contract fields
- docs work

#### Workstream C — Native App Surfaces

Ownership:

- `AgentLens/Services/BurnBarOperatingLayer.swift`
- `AgentLens/Views/Dashboard/DashboardView.swift`
- `AgentLens/Views/SessionLogs/SessionLogsView.swift`
- `AgentLens/Views/Popover/MenuBarPopoverView.swift`
- `AgentLens/Views/Popover/HermesPopoverChatView.swift`
- `AgentLens/Views/Settings/SettingsView.swift`

Parallelizable when:

- daemon contract names and payloads are known

Can run in parallel with:

- daemon runtime implementation
- registry/settings implementation

#### Workstream D — Scheduler / Registry / Settings

Ownership:

- project registry persistence
- daemon scheduler loop
- settings/project management UI

Primary files:

- `BurnBarDaemon/Sources/BurnBarDaemon/BurnBarMissionControlService.swift`
- `AgentLens/Views/Settings/SettingsView.swift`
- `AgentLens/Views/Dashboard/ProjectsView.swift`

This should be split carefully because `SettingsView` and the daemon service are
high-collision files.

#### Workstream E — Tests / Replay Fixtures

Ownership:

- `AgentLensTests/*`
- `BurnBarDaemon/Tests/*`
- `BurnBarCore/Tests/*`

Parallelizable with almost everything, as long as each worker owns a disjoint
test file set.

#### Workstream F — Docs / Canon

Ownership:

- `README.md`
- `docs/BURNBAR_RELEASE_ARCHITECTURE.md`
- `docs/BURNBAR_IMPLEMENTATION_CHECKLIST.md`
- `docs/ROADMAP.md`
- tranche plan docs

This can run in parallel the whole time, but final merge should happen after
implementation shape stabilizes.

### Recommended Parallel Waves

#### Wave 1

- Workstream A: contracts for controller ingestion + project registry
- Workstream B: daemon ingestion + scheduler foundations
- Workstream C: app-side registry/controller consumption using stable fields
- Workstream E: tests for new contract and daemon ingestion behavior

#### Wave 2

- Workstream B: review-run launch integration
- Workstream C: richer question UI + session-log routing
- Workstream D: registry/settings polish
- Workstream E: question flow and scheduled-run tests

#### Wave 3

- Workstream B: auto-takeover + mission executor integration
- Workstream C: auto-takeover/operator UX
- Workstream E: mission/auto-takeover tests

#### Wave 4

- Workstream A: connector/browser contracts
- Workstream B: connector/browser daemon tool plane
- Workstream F: docs refresh
- Workstream E: connector/browser/replay tests

#### Wave 5

- Workstream A: cloud-memory-sync contracts if still in scope
- Workstream B: memory-sync implementation or explicit de-scope
- Workstream F: architecture canon update

### Maximum Safe Parallelism

If staffing allows, the safest high-throughput layout is:

- 1 contract owner
- 1 daemon runtime owner
- 1 app/UI owner
- 1 scheduler/settings owner
- 1 tests/docs owner

That is the highest practical parallelism before merge friction starts to erase
the speed gains.

### Files To Avoid Sharing In The Same Wave

- `BurnBarDaemon/Sources/BurnBarDaemon/BurnBarMissionControlService.swift`
- `BurnBarDaemon/Sources/BurnBarDaemon/BurnBarRunService.swift`
- `AgentLens/Services/BurnBarOperatingLayer.swift`
- `AgentLens/Views/Settings/SettingsView.swift`
- `BurnBarCore/Sources/BurnBarCore/BurnBarMissionControlContracts.swift`

These should have a single owner per wave.

## Implementation Checklist

### Tranche 1

- [ ] Add daemon-owned ingestion from real BurnBar conversations, usage, scans, and summaries.
- [ ] Create a durable project registry model with cadence, aliases, and automation settings.
- [ ] Add scheduler loop for daily/weekly reviews.
- [ ] Expose project registry editing in Settings and/or Projects.
- [ ] Wire Telegram/UI review commands to real run launches in `BurnBarRunService`.
- [ ] Add tests covering scheduled launch, project registry persistence, and controller ingestion from real app data.

### Tranche 2

- [ ] Extend question contracts with stage labels, options, and deep-link metadata.
- [ ] Add dedicated new-question notification behavior.
- [ ] Add richer session-log and dashboard question flows.
- [ ] Add auto-takeover state/history/execution model.
- [ ] Connect mission packets/results to real worker execution.
- [ ] Add tests covering auto-takeover, packet execution, and question-tracker semantics.

### Tranche 3

- [ ] Define connector/browser contracts in `BurnBarCore`.
- [ ] Add daemon tool-plane support for external connectors/browser tasks.
- [ ] Decide and build cloud-canonical memory-sync architecture or explicitly de-scope it.
- [ ] Add CLI/control-plane entrypoints for controller/missions/followups/replay.
- [ ] Rewrite BurnBar docs to match the actual shipped architecture.

## Acceptance Criteria

### Tranche 1 acceptance

- Dashboard/menu/Hermes/session logs primarily reflect daemon-backed controller state derived from real product activity.
- BurnBar can register projects and run scheduled daily/weekly reviews without manual bookkeeping.
- Telegram/UI run actions launch real review execution, not only controller mutations.

### Tranche 2 acceptance

- Pending questions behave like real operator tasks, not lightweight prompt rows.
- BurnBar can auto-take over eligible stalled sessions with visible history and controls.
- Mission packets and mission results are linked to real worker execution.

### Tranche 3 acceptance

- BurnBar matches BurnBarDist’s broader operational surface or has an explicit documented divergence.
- BurnBar’s memory-sync stance is explicit: local canonical authority with optional cloud replicas.
- The architecture docs in BurnBar become the new canonical description of the product.

## Test Plan

- BurnBarCore:
  - contract round-trips for richer questions, project registry, connectors, and mission execution metadata
- BurnBarDaemon:
  - scheduler tests
  - ingestion tests from real BurnBar-derived inputs
  - run-launch tests from controller commands
  - auto-takeover lifecycle tests
  - mission execution linkage tests
  - connector/browser tests where added
- AgentLens:
  - dashboard/session-log/home/Hermes rendering tests for richer controller state
  - project registry UI tests
  - deep-link/new-question behavior tests
- Full regression:
  - `swift test --package-path BurnBarCore`
  - `swift test --package-path BurnBarDaemon`
  - `xcodebuild -scheme BurnBar -project BurnBar.xcodeproj -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO -only-testing:BurnBarTests`

## Notes

- Telegram, local notifications, and EventKit calendar externalization are no longer parity gaps.
- If we choose not to build the full cloud-canonical `memory-sync` architecture, we should document that as an intentional divergence from BurnBarDist rather than leaving it ambiguous.
