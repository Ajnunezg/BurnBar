# ProviderQuotaService Refactor Plan

## Why This Needs a Plan

`AgentLens/Services/ProviderQuota/ProviderQuotaService.swift` is 2764 lines and currently mixes:

- quota domain types and settings enums
- an `@Observable` service coordinator
- provider-specific adapters for Codex, Claude, MiniMax, ZAI, Factory, and Cursor
- persistence and file-system code
- Claude bridge install/remove/status management
- generic HTTP and JSON parsing helpers
- Codex rollout scanning and cache models
- internal transport/error models

That is too much responsibility for one type, and it makes every quota bug feel like editing a kitchen-sink file with network, filesystem, parsing, and UI-facing state all tangled together.

## Current Fault Lines

- `AgentLens/Services/ProviderQuota/ProviderQuotaService.swift:3` through `:259` defines domain and settings types.
- `AgentLens/Services/ProviderQuota/ProviderQuotaService.swift:264` through `:536` is the observable service shell.
- `AgentLens/Services/ProviderQuota/ProviderQuotaService.swift:540` through `:1217` contains provider-specific fetching logic.
- `AgentLens/Services/ProviderQuota/ProviderQuotaService.swift:1221` through `:1318` handles persistence and filesystem concerns.
- `AgentLens/Services/ProviderQuota/ProviderQuotaService.swift:1346` through `:2609` contains generic request/parsing/normalization helpers and Codex scanning logic.
- `AgentLens/Services/ProviderQuota/ProviderQuotaService.swift:2614` through `:2764` contains internal models and errors.

## Non-Negotiables

- Keep `ProviderQuotaService.shared` and the current public refresh/snapshot API stable during the refactor.
- Do not change snapshot shape or user-visible status message wording unless tests are updated intentionally.
- Provider extraction must happen one provider at a time; no all-provider rewrite.
- Keep `@Observable` state updates on the main actor. Push I/O and parsing out, but keep state coordination stable.

## Target End State

`ProviderQuotaService.swift` becomes a thin observable coordinator that owns:

- `snapshotsByProvider`
- `errors`
- `isFetching`
- `activeProviders`
- `lastFetch`
- `claudeBridgeStatus`
- public refresh and lookup methods

Everything else moves behind focused collaborators:

- `ProviderQuotaTypes.swift`
- `ProviderQuotaSnapshotStore.swift`
- `ClaudeQuotaBridgeManager.swift`
- `ProviderQuotaAdapter.swift`
- `ProviderQuotaAdapterFactory.swift`
- `CodexQuotaAdapter.swift`
- `ClaudeQuotaAdapter.swift`
- `MiniMaxQuotaAdapter.swift`
- `ZAIQuotaAdapter.swift`
- `FactoryQuotaAdapter.swift`
- `CursorQuotaAdapter.swift`
- `FlexibleQuotaBucketNormalizer.swift`
- `CodexRolloutScanner.swift`
- `ProviderQuotaHTTPClient.swift`
- `ProviderQuotaModels.swift`
- `ProviderQuotaError.swift`

## Refactor Sequence

### Phase 0: Lock the Existing Behavior With Tests

`ProviderQuotaServiceTests` are already the backbone here. Before moving code, make sure they cover:

- Codex local rollout parsing and cache reuse
- Claude bridge install/remove/status behavior
- Claude local-bridge vs API-billing override behavior
- Factory exact vs estimated snapshots
- MiniMax/ZAI flexible bucket parsing
- Cursor cookie/user/usage flows

Gate:

- `xcodebuild -scheme BurnBar -project BurnBar.xcodeproj -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO -only-testing:BurnBarTests/ProviderQuotaServiceTests -only-testing:BurnBarTests/UsageAggregatorTests`

### Phase 1: Extract Pure Types and Errors

- Move domain enums/structs out first:
  - `ProviderQuotaSourceKind`
  - `ProviderQuotaConfidence`
  - `ProviderQuotaUnit`
  - `ProviderQuotaWindowKind`
  - `ProviderQuotaBucket`
  - `ProviderQuotaSnapshot`
  - `ClaudeQuotaBridgeStatus`
  - settings enums
- Move `QuotaServiceError` and internal Codable transport models out as well.

Why first:

- this is the lowest-risk move
- it reduces the coordinator file immediately
- it gives every later adapter extraction a stable type home

### Phase 2: Extract Persistence and Bridge Management

Move out the stateful-but-not-coordinator concerns:

- snapshot persistence (`loadPersistedSnapshots`, `persistSnapshots`)
- Codex rollout scan-cache persistence
- parent-directory and JSON file helpers
- Claude bridge install/remove/status refresh

Suggested owners:

- `ProviderQuotaSnapshotStore` for persisted snapshots and Codex scan cache
- `ClaudeQuotaBridgeManager` for install/remove/status behavior

Critical rule:

- keep file formats and on-disk paths identical during the extraction

### Phase 3: Introduce a Real Adapter Boundary

Add a thin protocol:

- one adapter per provider
- one request context object carrying shared dependencies like `URLSession`, `environment`, `appPaths`, `homeDirectoryURL`, `keyStore`, and `DataStore`

Example responsibility split:

- the coordinator decides when to refresh and how to publish state
- the adapter knows how to fetch one provider's snapshot

Do not over-abstract yet. A simple protocol and factory is enough.

### Phase 4: Extract Providers One at a Time

Recommended order:

1. `CodexQuotaAdapter`
2. `ClaudeQuotaAdapter`
3. `FactoryQuotaAdapter`
4. `MiniMaxQuotaAdapter`
5. `ZAIQuotaAdapter`
6. `CursorQuotaAdapter`

Why this order:

- Codex and Claude are strongly covered and mostly local-state driven
- Factory has clearer API semantics than MiniMax and ZAI
- MiniMax and ZAI lean heavily on the flexible normalizer
- Cursor has multiple endpoint shapes and cookie/session coupling

Rule for every provider extraction:

- move one provider
- keep snapshot text and bucket labels stable
- run targeted tests
- merge before moving the next provider

### Phase 5: Extract the Flexible Parsing/Normalization Layer

The helpers around:

- `extractFlexibleBuckets`
- `recurseBuckets`
- `makeBucket`
- `inferWindowKind`
- `inferUnit`
- `inferPercent`
- fuzzy JSON key matching

should move into `FlexibleQuotaBucketNormalizer.swift`.

This should happen after the adapter boundary exists, not before. Otherwise the helper extraction turns into a giant speculative abstraction pass.

Goal:

- MiniMax, ZAI, and any future "messy JSON" provider share one normalization engine
- provider adapters become smaller and easier to reason about

### Phase 6: Isolate Codex Rollout Scanning

`fetchCodexSnapshot` currently owns:

- candidate directory discovery
- detached filesystem scanning
- cache reuse
- JSONL tail parsing
- rate-limit window normalization

That should become `CodexRolloutScanner`.

If the code still feels concurrency-fragile after extraction, make the scanner an `actor` so cache mutation is isolated away from the observable service.

### Phase 7: Reduce `ProviderQuotaService` to a Coordinator

After the extractions above, the main service file should only:

- expose the observable state
- coordinate refresh lifecycles
- call into the adapter factory
- persist refreshed snapshots through the snapshot store
- refresh bridge status through the bridge manager

No provider-specific `if provider == ...` branches should remain outside the adapter factory.

## Suggested File Layout

- `AgentLens/Services/ProviderQuota/ProviderQuotaService.swift`
- `AgentLens/Services/ProviderQuota/ProviderQuotaTypes.swift`
- `AgentLens/Services/ProviderQuota/ProviderQuotaError.swift`
- `AgentLens/Services/ProviderQuota/ProviderQuotaModels.swift`
- `AgentLens/Services/ProviderQuota/ProviderQuotaSnapshotStore.swift`
- `AgentLens/Services/ProviderQuota/ClaudeQuotaBridgeManager.swift`
- `AgentLens/Services/ProviderQuota/ProviderQuotaAdapter.swift`
- `AgentLens/Services/ProviderQuota/ProviderQuotaAdapterFactory.swift`
- `AgentLens/Services/ProviderQuota/CodexQuotaAdapter.swift`
- `AgentLens/Services/ProviderQuota/ClaudeQuotaAdapter.swift`
- `AgentLens/Services/ProviderQuota/FactoryQuotaAdapter.swift`
- `AgentLens/Services/ProviderQuota/MiniMaxQuotaAdapter.swift`
- `AgentLens/Services/ProviderQuota/ZAIQuotaAdapter.swift`
- `AgentLens/Services/ProviderQuota/CursorQuotaAdapter.swift`
- `AgentLens/Services/ProviderQuota/FlexibleQuotaBucketNormalizer.swift`
- `AgentLens/Services/ProviderQuota/CodexRolloutScanner.swift`
- `AgentLens/Services/ProviderQuota/ProviderQuotaHTTPClient.swift`

## Safety Rails

- Keep public status strings stable unless intentionally changed.
- Keep bucket ordering stable; UI and tests depend on it.
- Do not mix provider extraction with retry-policy or timeout-policy changes.
- Any helper shared by multiple adapters must get direct unit coverage before the second adapter adopts it.
- If a provider still feels unstable after extraction, keep the old implementation behind a temporary feature flag only within the branch, not long-term in `main`.

## Suggested PR Breakdown

1. `ProviderQuota: extract types, models, and errors`
2. `ProviderQuota: extract snapshot persistence and Claude bridge manager`
3. `ProviderQuota: introduce adapter protocol and move Codex + Claude`
4. `ProviderQuota: move Factory`
5. `ProviderQuota: extract flexible normalizer and move MiniMax + ZAI`
6. `ProviderQuota: move Cursor and shrink coordinator`

## Definition of Done

- `ProviderQuotaService.swift` is a coordinator, not a kitchen-sink implementation
- provider-specific logic lives in one file per provider
- persistence, bridge management, and parsing are split out cleanly
- `ProviderQuotaServiceTests` still pass
- adding a new provider no longer means editing a 2700-line file full of unrelated code
