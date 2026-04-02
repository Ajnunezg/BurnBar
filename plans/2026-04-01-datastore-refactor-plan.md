# DataStore Refactor Plan

## Why This Needs a Plan

`AgentLens/Services/DataStore.swift` is 6083 lines and currently mixes four different jobs:

- app-facing observable state and dashboard aggregates
- database bootstrap plus the full migrator (`v1` through `v26`)
- usage, conversation, chat, control-plane, and device APIs
- an embedded `LocalSearchStore` implementation that duplicates a second storage layer inside the same file

There is also an important repo reality: a partial refactor already exists under `AgentLens/Services/DataStore/`:

- `BurnBarDatabase.swift`
- `UsageStore.swift`
- `ConversationStore.swift`
- `SearchIndexStore.swift`
- `ArtifactStore.swift`
- `ProjectionStore.swift`
- `ControlPlaneStore.swift`
- `DeviceStore.swift`

The safest path is not to invent a third shape. The safest path is to finish the extraction that already started, make those files the single source of truth, and reduce `DataStore.swift` to a thin `@Observable` facade.

## Current Fault Lines

- `AgentLens/Services/DataStore.swift:101` starts the observable `DataStore`.
- `AgentLens/Services/DataStore.swift:395` through roughly `AgentLens/Services/DataStore.swift:1231` owns initialization and all schema migrations.
- `AgentLens/Services/DataStore.swift:2152` through `AgentLens/Services/DataStore.swift:3290` already delegates large chunks of search/artifact/projection/control-plane work into `localSearchStore`.
- `AgentLens/Services/DataStore.swift:3732` through `AgentLens/Services/DataStore.swift:6083` defines a second giant storage implementation inline as `LocalSearchStore`.

That means the file is not just large. It is actively carrying duplicated architectural intent:

- the new extracted store files under `AgentLens/Services/DataStore/`
- the older inline `LocalSearchStore`
- the public `DataStore` facade

That duplication is the real bug.

## Non-Negotiables

- No big-bang rewrite.
- No schema changes during the structural refactor unless a separate migration is explicitly required.
- `DataStore` must keep its existing public API during the cutover so views, services, and tests do not all churn at once.
- Every phase must compile and ship independently.
- At the end of each phase there must be exactly one authoritative implementation for the moved domain.

## Target End State

`DataStore.swift` becomes a facade of roughly 300-500 lines that owns:

- `@Observable` / `@MainActor` state
- `usages`, `rollingDailyAverage`, `lastRefresh`, and dashboard computed properties
- orchestration across focused stores
- compatibility shims only where still needed

Focused files become the real persistence layer:

- `BurnBarDatabase.swift`: queue ownership, migrator, shared codecs/helpers
- `UsageStore.swift`: `token_usage` CRUD, refresh reads, sync helpers, summaries
- `ConversationStore.swift`: conversations, chat threads/messages, summaries, transcript scans, session logs
- `SearchIndexStore.swift`: search documents/chunks, FTS, lexical search
- `ArtifactStore.swift`: source artifacts, sync state, permissions, audit
- `ProjectionStore.swift`: projection jobs, embeddings, retrieval health, schema inventory
- `ControlPlaneStore.swift`: operating action history, controller runtime mirror
- `DeviceStore.swift`: devices and device summaries

## Refactor Sequence

### Phase 0: Freeze Behavior Before Moving Anything

- Add characterization tests around the public `DataStore` facade before more code moves.
- Prefer contract-style tests that seed an in-memory DB and assert returned records, counts, and ordering.
- Lock down the following behavior specifically:
  - migration bootstrap and empty-store initialization
  - `refresh()` population of `usages`
  - sync flows (`fetchUnsynced`, `markSynced`, conversation sync variants)
  - controller runtime mirror reads and mutations
  - search document/chunk CRUD and lexical search
  - artifact, projection, embedding, and retrieval-health flows

Gate:

- `xcodebuild -scheme BurnBar -project BurnBar.xcodeproj -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO -only-testing:BurnBarTests/DataStoreTests -only-testing:BurnBarTests/BurnBarMigrationTests -only-testing:BurnBarTests/ConversationParsingTests -only-testing:BurnBarTests/AgentLensTests`

### Phase 1: Make the Shared Database Spine Real

- Change `DataStore` to own a `BurnBarDatabase` instance instead of owning migration logic itself.
- Move all migration registration and shared parsing/encoding helpers out of `DataStore.swift` and into `BurnBarDatabase.swift`.
- Keep the migration names and ordering byte-for-byte identical.
- Do not touch table definitions, defaults, or indexes in this phase.

Deliverable:

- `DataStore.init(...)` calls `BurnBarDatabase.runMigrations()`.
- `DataStore.swift` no longer contains the `migrator` implementation.

Risk to watch:

- Migration drift from copy/paste edits. Treat the extracted `BurnBarDatabase` migrator as a literal lift, not a cleanup pass.

### Phase 2: Finish Dependency Injection Inside `DataStore`

- Add stored properties in `DataStore` for:
  - `usageStore`
  - `conversationStore`
  - `searchIndexStore`
  - `artifactStore`
  - `projectionStore`
  - `controlPlaneStore`
  - `deviceStore`
- Instantiate them from the same `DatabaseQueue`.
- Stop using the inline `LocalSearchStore` as the aggregation point for unrelated domains.

Deliverable:

- `DataStore` delegates to the extracted store files, not to an embedded mega-helper.

### Phase 3: Move Usage and Device Behavior First

Why first:

- usage state is the heart of the facade
- `UsageStore.swift` and `DeviceStore.swift` already exist
- the blast radius is lower than conversations or search

Steps:

- Route insert/delete/sync/refresh logic through `UsageStore`.
- Keep `usages`, `replaceUsages`, `rollingDailyAverage`, `moodBand`, and dashboard aggregates in `DataStore`.
- Route device CRUD and summaries through `DeviceStore`.
- Keep any UI-facing computed summaries on the facade.

Deliverable:

- `DataStore.swift` stops owning raw `token_usage` SQL.

### Phase 4: Move Conversation, Chat, and Session-Log APIs

- Route conversation CRUD, summary flows, chat thread/message flows, transcript scanning, and session-log helpers through `ConversationStore`.
- Preserve existing method names on `DataStore` so callers do not change yet.
- Only after parity is proven should helper mapping functions be removed from `DataStore.swift`.

Risk to watch:

- summary-preservation logic is subtle
- session-log ordering and transcript snippets are user-visible behavior
- chat thread behavior is already covered by app features and tests, so do not silently rename or normalize fields in this phase

Gate:

- `BurnBarTests/ConversationParsingTests`
- `BurnBarTests/AgentLensTests`
- `BurnBarTests/DataStoreTests`

### Phase 5: Cut Search, Artifact, Projection, and Control-Plane Domains Fully Over

- Replace `localSearchStore` delegation with direct delegation to:
  - `SearchIndexStore`
  - `ArtifactStore`
  - `ProjectionStore`
  - `ControlPlaneStore`
- Delete the duplicated domain methods from the inline `LocalSearchStore` only after the facade is pointing at the extracted classes.
- Keep method signatures on `DataStore` stable.

Critical rule:

- when a public method is cut over, the old inline implementation must be deleted in the same branch before merge

This is the point where the current architectural danger disappears.

### Phase 6: Delete `LocalSearchStore`

- Remove the inline `private struct LocalSearchStore` from `DataStore.swift`.
- Remove duplicate row-mapping helpers that now live in focused stores or `BurnBarDatabase`.
- Keep only facade-level helpers that are genuinely about in-memory state or cross-store orchestration.

Done means:

- `DataStore.swift` contains no embedded storage subsystem
- each table family has one implementation owner

### Phase 7: Optional Final Cleanup

- Consider renaming `DataStore.swift` to `DataStoreFacade.swift` only if the team wants the name to communicate the new role.
- Do not do this in the same PR as the extraction unless the branch is already fully green.

## File Layout To Land

Keep using the folder that already exists:

- `AgentLens/Services/DataStore/BurnBarDatabase.swift`
- `AgentLens/Services/DataStore/UsageStore.swift`
- `AgentLens/Services/DataStore/ConversationStore.swift`
- `AgentLens/Services/DataStore/SearchIndexStore.swift`
- `AgentLens/Services/DataStore/ArtifactStore.swift`
- `AgentLens/Services/DataStore/ProjectionStore.swift`
- `AgentLens/Services/DataStore/ControlPlaneStore.swift`
- `AgentLens/Services/DataStore/DeviceStore.swift`
- `AgentLens/Services/DataStore.swift`

Do not create another nested abstraction layer until this cutover is complete.

## Safety Rails

- Keep `DataStore` method names stable until the very end.
- Prefer moving code without changing behavior, then clean up behavior in follow-up PRs.
- Do not change SQL shape and code shape in the same commit if you can avoid it.
- For every moved domain, add or keep one in-memory parity test that compares old facade behavior against the extracted store behavior.
- Do not leave copied helper functions in both places after a phase lands.

## Suggested PR Breakdown

1. `DataStore: wire BurnBarDatabase and remove inline migrator`
2. `DataStore: delegate usage and device persistence to focused stores`
3. `DataStore: delegate conversation/chat/session-log flows`
4. `DataStore: delegate search/artifact/projection/control-plane flows`
5. `DataStore: remove inline LocalSearchStore and dead helpers`

Each PR should stay reviewable, compile independently, and include only one domain family plus tests.

## Definition of Done

- `DataStore.swift` is no longer a monolith and no longer contains migration definitions or `LocalSearchStore`
- the extracted files under `AgentLens/Services/DataStore/` are the only persistence implementation
- all existing `DataStore` callers compile without broad signature churn
- targeted tests pass
- new work can add persistence behavior by editing one focused file instead of one 6000-line file
