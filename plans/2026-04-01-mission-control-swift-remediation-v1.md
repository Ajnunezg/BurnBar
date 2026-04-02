# MissionControl Module - Remediation Plan

## Objective

Address the **actual** issues identified in the MissionControl/BurnBarDaemon implementation rather than the placeholder file which is intentional for source compatibility.

---

## Implementation Plan

### Phase 1: Critical Error Handling Issues

- [ ] **1.1 Replace `fatalError` with graceful degradation** in `BurnBarCore/Sources/BurnBarCore/BurnBarCatalog.swift:242-249`
  
  Replace the `fatalError` in `BurnBarCatalogLoader.bundledCatalog` with a fallback mechanism:
  - Return a minimal default catalog if bundled catalog fails to load
  - Log a warning instead of crashing
  - Allow the app to continue with degraded functionality

- [ ] **1.2 Audit and fix silent error swallowing** across the codebase
  
  The following locations use `try?` or `try!` that silently ignore errors:
  
  | File | Line | Issue |
  |------|------|-------|
  | `BurnBarCore/BurnBarSearchPlanner.swift` | 838, 849 | `try? NSRegularExpression` |
  | `BurnBarCore/BurnBarJSONValue.swift` | 16-26 | Multiple `try? container.decode` |
  | `BurnBarDaemon/BurnBarRunService.swift` | 169 | `try? await restorePersistedRunsIfNeeded()` |
  | `BurnBarDaemon/BurnBarUsageRecorder.swift` | 127 | `try? handle.close()` |
  
  For each location:
  - Determine if errors should be propagated or just logged
  - Add logging for non-critical errors
  - Consider adding metrics/observability for error rates

### Phase 2: Swift 6 / Sendable Compliance

- [ ] **2.1 Address Sendable conformance warnings** documented in QA Report M2
  
  Files with `FileManager` stored properties:
  - `FactoryDroidParser`
  - `KimiParser`
  - `CopilotParser`
  - `AiderParser`
  
  Options:
  - Make parsers `@MainActor` isolated (already the case per QA report)
  - Remove `FileManager` property and use static/global access
  - Suppress warnings with `@preconcurrency` if safe

- [ ] **2.2 Add `@unchecked Sendable` annotations** where thread safety is manually managed

### Phase 3: Testing Coverage

- [ ] **3.1 Add unit tests for MissionControlStore**
  
  Test coverage needed for:
  - Event sourcing: append, replay, rebuild projection
  - Project CRUD operations
  - Question lifecycle: create, answer, dismiss
  - Followup lifecycle: create, snooze, complete, calendar
  - Mission lifecycle: create, approve, dispatch, record results
  - Notification evaluation logic
  - Telegram command parsing

- [ ] **3.2 Add integration tests for MissionControlService**
  
  Test coverage needed for:
  - Background notification loop
  - Controller activity ingestion
  - Scheduled review launches
  - Mission execution synchronization
  - Auto-takeover logic

- [ ] **3.3 Add tests for notification bridges**
  
  Test coverage needed for:
  - `LocalNotificationBridge` (mock `osascript`)
  - `TelegramBotBridge` (mock HTTP responses)
  - `EventKitBridge` (mock EventKit)

### Phase 4: Code Quality Improvements

- [ ] **4.1 Convert webview JS to TypeScript**
  
  Files to convert:
  - `extensions/burnbar/src/webview/workspace.js` → `workspace.ts`
  - `extensions/burnbar/src/webview/panel.js` → `panel.ts`
  
  Benefits:
  - Type safety for webview communication
  - Consistent linting rules
  - Better IDE support

- [ ] **4.2 Consolidate duplicated helper functions**
  
  Identified duplicates from QA Report L1:
  - `formatCost`: 6+ copies across view files
  - `formatTokens`: 4+ copies across view files
  
  Action: Create shared utilities in `AgentLens/Utilities/`

- [ ] **4.3 Remove dead code**
  
  From QA Report L2:
  - `FactorySettings` struct in `FactoryDroidParser.swift:252` - declared but unused

### Phase 5: Performance Optimization

- [ ] **5.1 Fix ISO8601DateFormatter allocation in loops** (QA Report L5)
  
  Files affected:
  - Multiple parser files create `ISO8601DateFormatter()` inside loops
  
  Solution:
  - Use a static/shared formatter instance
  - Or use a date parsing utility with caching

- [ ] **5.2 Consider lazy loading for large datasets**
  
  The store loads all events into memory on `ensureLoaded()`.
  For large datasets:
  - Consider pagination for events
  - Consider background indexing

---

## Verification Criteria

1. **Error Handling**: App no longer crashes on missing/malformed catalog
2. **Sendable Compliance**: No compiler warnings with Swift 6 mode
3. **Test Coverage**: At least 70% coverage on MissionControl module
4. **Code Quality**: No remaining TODO comments for code-related items
5. **Performance**: No DateFormatter allocations in tight loops

---

## Potential Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Breaking catalog validation | Add migration path; maintain backwards compatibility |
| Sendable changes affect thread safety | Thorough testing; maintain @MainActor isolation |
| Test coverage additions slow development | Prioritize critical paths first |
| Performance changes introduce regressions | Benchmark before/after; add performance tests |

---

## Alternative Approaches

### Alternative 1: Keep fatalError with better error messages
- Pros: Simpler, maintains current behavior
- Cons: Still crashes on startup; bad UX

### Alternative 2: Async initialization with graceful degradation
- Pros: App starts, shows warning banner
- Cons: More complex state management

### Alternative 3: Full rewrite of error handling
- Pros: Comprehensive fix, clean error types
- Cons: High effort, risk of regressions
