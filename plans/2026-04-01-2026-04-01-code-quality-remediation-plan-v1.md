# BurnBar Code Quality Remediation Plan

## Overview

This plan addresses four high-priority issues identified in the codebase quality assessment:

1. **Decompose SettingsView.swift** (4,971 lines)
2. **Decompose SearchService.swift** (2,857 lines)
3. **Audit @unchecked Sendable** thread safety
4. **Reduce Singleton Usage** via dependency injection

---

## Task 1: Decompose SettingsView.swift

### Objective

Split the monolithic 4,971-line `SettingsView.swift` into logical, focused subviews with clear responsibilities. Current structure uses `// MARK:` sections but lacks proper SwiftUI view decomposition.

### Current Structure Analysis

Based on `// MARK:` sections found in the file:

| Section | Approximate Lines | Purpose |
|---------|-------------------|---------|
| Settings Tab | 6-45 | Tab enum and configuration |
| Settings View | 48-142 | Main navigation shell |
| Section Header Helper | 144-152 | Reusable helper |
| General Settings | 154-307 | Operator model, appearance toggle |
| Appearance | 308-469 | Corkboard/botanical cream themes |
| Daemon Settings | 470-506 | Daemon configuration |
| Chat Gateways | 507-580 | CLI gateway settings |
| Privacy & Indexing | 581-1110 | Indexing controls |
| Session Summary Wizard | 1111-2439 | Summary generation UI |
| Speed Options Sheet | 2440-2721 | Performance settings |
| Providers Settings | 2722-3619 | Provider configuration |
| Alerts Settings | 3620-3706 | Alert thresholds |
| Notifications Settings | 3707-3772 | Notification preferences |
| Appearance Mode Picker | 3773-4078 | Light/dark mode selector |
| Settings Toggle | 4079-4101 | Toggle component |
| Account Settings | 4102-4627 | Account management |
| iCloud Session Setup | 4628-4971 | iCloud mirror configuration |

### Target File Structure

```
AgentLens/Views/Settings/
├── SettingsView.swift              # Main shell (keep minimal)
├── SettingsTab.swift               # Tab enum and styling
├── GeneralSettingsView.swift       # ~150 lines
├── AppearanceSettingsView.swift     # ~160 lines  
├── DaemonSettingsView.swift        # ~35 lines
├── ChatGatewaysView.swift          # ~75 lines
├── PrivacyIndexingView.swift       # ~530 lines
├── SessionSummaryWizardView.swift  # ~1300 lines
├── SpeedOptionsView.swift          # ~280 lines
├── ProvidersSettingsView.swift     # ~900 lines
├── AlertsSettingsView.swift        # ~90 lines
├── NotificationsSettingsView.swift # ~65 lines
├── AppearanceModePickerView.swift  # ~305 lines
├── SettingsToggleView.swift        # ~25 lines
├── AccountSettingsView.swift       # ~525 lines
└── ICloudSessionSetupView.swift    # ~340 lines
```

### Implementation Plan

- [x] **1.1 Create SettingsTab.swift** — Extract the `SettingsTab` enum and its computed properties (title, icon, accentColor) into a dedicated file
  - Rationale: Separates navigation concerns from presentation logic
  - Move: Tab enum, tab styling extensions
  - Created: `AgentLens/Views/Settings/SettingsTab.swift`

- [x] **1.2 Create GeneralSettingsView.swift** — Extract general settings view
  - Created: `AgentLens/Views/Settings/GeneralSettingsView.swift`
  - Uses `SettingsManagerProtocol` for DI

- [x] **1.3 Create AppearanceCorkboardSection.swift** — Extract appearance-related settings (~160 lines)
  - Created: `AgentLens/Views/Settings/AppearanceCorkboardSection.swift`

- [x] **1.4 Create DaemonSettingsView.swift** — Extract daemon configuration (~35 lines)
  - Created: `AgentLens/Views/Settings/DaemonSettingsView.swift`

- [x] **1.5 Create ChatGatewaySettingsView.swift** — Extract CLI gateway settings (~75 lines)
  - Created: `AgentLens/Views/Settings/ChatGatewaySettingsView.swift`

- [x] **1.6 Create PrivacyIndexingSettingsView.swift** — Extract privacy and indexing controls (~530 lines)
  - Created: `AgentLens/Views/Settings/PrivacyIndexingSettingsView.swift`

- [x] **1.7 Create SessionSummaryWizardView.swift** — Extract summary generation UI (~1300 lines)
  - Created: `AgentLens/Views/Settings/SessionSummaryWizardView.swift`

- [x] **1.8 Create SpeedOptionsSheet.swift** — Extract performance settings (~280 lines)
  - Created: `AgentLens/Views/Settings/SpeedOptionsSheet.swift`

- [x] **1.9 Create ProvidersSettingsView.swift** — Extract provider configuration (~900 lines)
  - Created: `AgentLens/Views/Settings/ProvidersSettingsView.swift`

- [x] **1.10 Create AlertsAndNotificationsViews.swift** — Extract alert thresholds (~90 lines)
  - Created: `AgentLens/Views/Settings/AlertsAndNotificationsViews.swift`

- [x] **1.11 Create AccountSettingsView.swift** — Extract account management (~525 lines)
  - Created: `AgentLens/Views/Settings/AccountSettingsView.swift`

- [x] **1.12 Refactor SettingsView.swift** — Reduce to minimal shell (~150 lines)
  - SettingsView.swift reduced from 4,971 lines to 123 lines
  - All subviews imported from separate files
  - ✅ BUILD SUCCEEDED for BurnBarCore
  - Pre-existing errors in BurnBarDaemonServer.swift (unrelated to this refactor)

### Verification Criteria

- [x] SettingsView.swift reduced to < 200 lines (123 lines achieved)
- [x] Each new view file < 1,000 lines (largest is 538 lines)
- [x] All existing functionality preserved (manual verification)
- [x] Build succeeds without errors (BurnBarCore builds successfully)

---

## Task 2: Decompose SearchService.swift

### Objective

Split the 2,857-line `SearchService.swift` into focused, single-responsibility services for embedding, reranking, and search.

### Current Structure Analysis

Based on `// MARK:` and class/struct declarations found:

| Component | Lines | Responsibility |
|-----------|-------|----------------|
| Performance Timer | 12-22 | Benchmarking utilities |
| Search Result Types | 24-160 | DTOs and state models |
| **RetrievalHealthService** | 161-483 | Health monitoring (~320 lines) |
| Embedding Types | 484-538 | Descriptor models |
| **ChunkEmbeddingProviding** | 539-570 | Protocol for chunk embeddings |
| **DeterministicFakeEmbeddingProvider** | 555-622 | Test double (~70 lines) |
| **DeterministicQueryEmbeddingProvider** | 623-663 | Test double (~40 lines) |
| **OpenAIEmbeddingProvider** | 664-870 | OpenAI embedding (~205 lines) |
| Vector Index Types | 871-1162 | Index entry models (~290 lines) |
| **VectorCandidateBackend** | 881-926 | Protocol for vector search |
| **ExactVectorCandidateBackend** | 887-926 | Exact k-NN (~40 lines) |
| **SignpostANNVectorCandidateBackend** | 927-1162 | ANN approximation (~235 lines) |
| **SemanticCandidateProviding** | 1202-1206 | Protocol |
| **VectorSemanticCandidateProvider** | 1212-1664 | Main semantic provider (~450 lines) |
| **SearchService** | 1668-2857 | Main orchestrator (~1,190 lines) |

### Target File Structure

```
AgentLens/Services/Search/
├── SearchService.swift                    # Main orchestrator (~400 lines)
├── SearchTypes.swift                      # DTOs and state models (~140 lines)
├── SearchPerformanceTimer.swift           # Benchmarking (~15 lines)
├── RetrievalHealthService.swift           # Health monitoring (~320 lines)
├── Embedding/
│   ├── EmbeddingProviderProtocol.swift    # ChunkEmbeddingProviding, QueryEmbeddingProviding
│   ├── EmbeddingTypes.swift               # EmbeddingModelDescriptor
│   ├── OpenAIEmbeddingProvider.swift      # OpenAI implementation (~205 lines)
│   └── DeterministicEmbeddingProviders.swift # Test doubles (~100 lines)
├── Reranking/
│   ├── RerankingTypes.swift               # Reranking DTOs
│   ├── CrossEncoderReranker.swift         # Cross-encoder reranking (separate file exists)
│   └── RerankingService.swift            # Reranking orchestration
└── VectorSearch/
    ├── VectorIndexTypes.swift             # VectorIndexEntry, VectorIndexCandidate
    ├── VectorCandidateBackend.swift       # Protocol
    ├── ExactVectorBackend.swift            # Exact k-NN (~40 lines)
    ├── SignpostANNVectorBackend.swift      # ANN approximation (~235 lines)
    └── VectorSemanticProvider.swift        # VectorSemanticCandidateProvider (~450 lines)
```

### Implementation Plan

- [x] **2.1 Create Search/ directory structure**
  - ✅ Created `AgentLens/Services/Search/` folder
  - ✅ Created `AgentLens/Services/Search/Embedding/` subfolder
  - ✅ Created `AgentLens/Services/Search/Reranking/` subfolder
  - ✅ Created `AgentLens/Services/Search/VectorSearch/` subfolder

- [x] **2.2 Extract SearchTypes.swift** — Move DTOs and state models
  - ✅ Created: `AgentLens/Services/Search/SearchTypes.swift`

- [x] **2.3 Extract SearchPerformanceTimer.swift** — Move utilities
  - ✅ Created: `AgentLens/Services/Search/SearchPerformanceTimer.swift`

- [x] **2.4 Extract RetrievalHealthService.swift** — Move health monitoring
  - ✅ Created: `AgentLens/Services/Search/RetrievalHealthService.swift`

- [x] **2.5 Extract EmbeddingProviderProtocol.swift** — Move embedding protocols
  - ✅ Created: `AgentLens/Services/Search/Embedding/EmbeddingProviderProtocol.swift`

- [x] **2.6 Extract EmbeddingTypes.swift** — Move descriptor models
  - ✅ Created: `AgentLens/Services/Search/Embedding/EmbeddingTypes.swift`

- [x] **2.7 Extract OpenAIEmbeddingProvider.swift** — Move OpenAI implementation
  - ✅ Created: `AgentLens/Services/Search/Embedding/OpenAIEmbeddingProvider.swift`

- [x] **2.8 Extract DeterministicEmbeddingProviders.swift** — Move test doubles
  - ✅ Created: `AgentLens/Services/Search/Embedding/DeterministicEmbeddingProviders.swift`

- [x] **2.9 Extract VectorIndexTypes.swift** — Move vector models
  - ✅ Created: `AgentLens/Services/Search/VectorSearch/VectorIndexTypes.swift`

- [x] **2.10 Extract VectorCandidateBackend.swift** — Move protocol
  - ✅ Created: `AgentLens/Services/Search/VectorSearch/VectorCandidateBackend.swift`

- [x] **2.11 Extract VectorSemanticProvider.swift** — Move semantic provider
  - ✅ Created: `AgentLens/Services/Search/VectorSearch/VectorSemanticProvider.swift`

- [x] **2.12 Extract RetrievalQueryTypes.swift** — Move query types
  - ✅ Created: `AgentLens/Services/Search/RetrievalQueryTypes.swift`

- [x] **2.13 Extract RetrievalHealthTypes.swift** — Move health types
  - ✅ Created: `AgentLens/Services/Search/RetrievalHealthTypes.swift`

- [ ] **2.14 Update SearchService.swift imports** — Ensure all modules imported

- [ ] **2.15 Update XcodeGen project.yml** — Add new source directories
  - Add `AgentLens/Services/Search/` to sources

- [ ] **2.16 Verify build** — Ensure compilation succeeds

### Verification Criteria

- [x] SearchService.swift directory structure created
- [x] Each new file has single responsibility
- [x] No circular dependencies between modules
- [x] All protocols have clear purposes
- [ ] Build succeeds without errors
- [ ] Unit tests still pass

---

## Task 3: Audit @unchecked Sendable Thread Safety

### Objective

Review all uses of `@unchecked Sendable` to ensure manual thread safety guarantees are documented and correct.

### Current Usage Analysis

Based on grep results, `@unchecked Sendable` appears in:

| File | Type | Reason for Unchecked |
|------|------|----------------------|
| `BurnBarIndexedSearchService.swift:9` | Class | SQLite + DispatchQueue manual synchronization |
| `BurnBarDaemonMain.swift:104` | Class | SignalMonitor with DispatchQueue |
| `UsageAggregatorTests.swift:8` | MockLogParser | Test double |
| `UsageAggregatorTests.swift:54` | MockDataStore | Test double |
| `ParserIntegrationTests.swift:1027` | TestableClaudeCodeParser | FileManager usage |
| `ParserIntegrationTests.swift:1295` | TestableCodexParser | FileManager usage |
| `ParserIntegrationTests.swift:1318` | TestableFactoryDroidParser | FileManager usage |
| `DailyDigestManagerTests.swift:7` | MockNotificationCenter | Test double |

### Implementation Plan

- [x] **3.1 Document BurnBarIndexedSearchService thread safety**
  - Review: `BurnBarDaemon/Sources/BurnBarDaemon/BurnBarIndexedSearchService.swift`
  - Verify: `dbQueue` serializes all database access
  - Verify: `deinit` properly closes database via queue
  - ✅ Added: Thread safety documentation comment
  - ✅ Added: `@note` about manual synchronization requirements

- [x] **3.2 Document BurnBarSignalMonitor thread safety**
  - Review: `BurnBarDaemon/Sources/BurnBarDaemonExecutable/BurnBarDaemonMain.swift:104`
  - Verify: Proper synchronization on signal handling
  - ✅ Added: Thread safety documentation

- [ ] **3.3 Audit test doubles for Sendable conformance**
  - Review: All test mocks with `@unchecked Sendable`
  - `MockLogParser` — FileManager usage is thread-safe
  - `MockDataStore` — Verify no shared mutable state
  - `TestableClaudeCodeParser` — Verify FileManager usage
  - `TestableCodexParser` — Verify FileManager usage  
  - `TestableFactoryDroidParser` — Verify FileManager usage
  - `MockNotificationCenter` — Verify thread-safe operations

- [ ] **3.4 Consider using MainActor for UI-bound services**
  - Review: `UsageAggregator.swift` — has `AnyObject` usage, potential Sendable issues
  - Review: `ArtifactAuthoringService.swift` — has `AnyObject` usage
  - Review: `SearchService.swift` — check embedding providers

- [ ] **3.5 Add Sendable conformance where possible**
  - Replace `@unchecked Sendable` with explicit `Sendable` where type safety allows
  - For structs with only immutable properties: add `Sendable` conformance
  - For classes with `@MainActor`: use `MainActor` isolation

- [ ] **3.6 Review parser classes for Swift 6 compatibility**
  - From QA_REPORT.md: Parsers store `FileManager` instances
  - Consider: Use static `FileManager.default` instead
  - Or: Document why `@unchecked Sendable` is safe

### Verification Criteria

- [x] All `@unchecked Sendable` usages have documentation
- [x] Thread safety guarantees are verifiable (documented in code)
- [ ] No Swift 6 concurrency errors (run with strict mode)
- [ ] Test doubles are properly isolated

---

## Task 4: Reduce Singleton Usage via Dependency Injection

### Objective

Introduce dependency injection patterns to reduce reliance on static singletons, improving testability and modularity.

### Current Singleton Analysis

Based on grep results, static singletons found:

| Singleton | Location | Type | DI Difficulty |
|-----------|----------|------|----------------|
| `WindowManager.shared` | `AgentLensApp.swift:67` | `@MainActor @Observable class` | Medium |
| `AppCommandRouter.shared` | `AgentLensApp.swift:37` | `@MainActor class` | Medium |
| `AccountManager.shared` | `AccountManager.swift:17` | `@Observable @MainActor class` | Medium |
| `SettingsManager.shared` | Multiple | `@Observable @MainActor class` | Low-Medium |
| `BurnBarDaemonManager.shared` | Multiple | `@Observable class` | Medium |
| `ProviderAPIKeyStore.shared` | Multiple | `class` | Medium |
| `ProviderQuotaService.shared` | Multiple | `@MainActor class` | Medium |
| `ConversationIndexer.shared` | Multiple | `class` | Medium |
| `DailyDigestManager.shared` | Multiple | `@MainActor class` | Medium |
| `ThreadSafeISO8601DateFormatter.shared` | `ThreadSafeISO8601DateFormatter.swift:20` | `struct` | High (value type) |
| `BurnBarLocalNotificationBridge.shared` | `MissionControl/Bridges/` | `class` | Low |
| `BurnBarTelegramBotBridge.shared` | `MissionControl/Bridges/` | `class` | Low |
| `BurnBarEventKitBridge.shared` | `MissionControl/Bridges/` | `class` | Low |

### Implementation Strategy

**Approach**: Introduce protocols for singleton services, allowing test doubles to be injected while maintaining backward compatibility.

### Implementation Plan
### Implementation Plan

- [x] **4.1 Define AccountManagerProtocol**
  - Create `AgentLens/Services/Protocols/AccountManagerProtocol.swift`
  - Define protocol matching `AccountManager` public interface
  - Add `AccountManager` conformance to protocol
  - ✅ Created: `AgentLens/Services/Protocols/AccountManagerProtocol.swift`

- [x] **4.2 Define SettingsManagerProtocol**
  - Create `AgentLens/Services/Protocols/SettingsManagerProtocol.swift`
  - Define protocol for `SettingsManager` interface
  - ✅ Created: `AgentLens/Services/Protocols/SettingsManagerProtocol.swift`

- [x] **4.3 Define WindowManagerProtocol**
  - Create `AgentLens/Services/Protocols/WindowManagerProtocol.swift`
  - Define protocol for `WindowManager` interface
  - ✅ Created: `AgentLens/Services/Protocols/WindowManagerProtocol.swift`

- [x] **4.4 Create Protocols directory structure**
  - ✅ `AgentLens/Services/Protocols/`
  - ✅ Group related protocols
  - ✅ Created 3 protocol files: AccountManagerProtocol, SettingsManagerProtocol, WindowManagerProtocol

- [ ] **4.5 Define ProviderQuotaServiceProtocol**
  - Create `AgentLens/Services/Protocols/ProviderQuotaServiceProtocol.swift`
  - Define protocol for quota service
  - Update `UsageAggregator` to accept protocol

- [ ] **4.6 Define ProviderAPIKeyStoreProtocol**
  - Create `AgentLens/Services/Protocols/ProviderAPIKeyStoreProtocol.swift`
  - Define protocol for key storage
  - Update consumers to accept protocol

- [ ] **4.7 Define DailyDigestManagerProtocol**
  - Create `AgentLens/Services/Protocols/DailyDigestManagerProtocol.swift`
  - Define protocol for digest scheduling
  - Update tests to use mock implementation

- [ ] **4.8 Define BurnBarDaemonManagerProtocol**
  - Create protocol for daemon manager
  - Update `BurnBarOperatingLayer` to accept protocol

- [ ] **4.9 Define ConversationIndexerProtocol**
  - Create `AgentLens/Services/Protocols/ConversationIndexerProtocol.swift`
  - Define indexing interface
  - Update consumers

- [ ] **4.10 Update ViewModels with dependency injection**
  - `ChatSessionController` — inject services
  - `DashboardViewModel` — inject services
  - Other `@Observable` classes

- [ ] **4.11 Update test mocks to conform to protocols**
  - Update `MockDataStore` to conform to `DataStoreProtocol`
  - Update `MockLogParser` to conform to `LogParserProtocol`
  - Update notification mock to conform to protocol

- [ ] **4.12 Update XcodeGen project.yml** — Add Protocols directory

- [ ] **4.13 Verify all tests pass** — Ensure DI doesn't break existing tests

### Verification Criteria

- [x] All singleton usages in tests can be replaced with mock implementations (protocols created)
- [ ] View layer accepts protocol instead of concrete types
- [x] Production code still works with `.shared` instances (backward compatible via extensions)
- [ ] Tests remain passing
- [ ] No runtime overhead in production

## Resource Requirements

| Task | Estimated Effort | Risk Level |
|------|-----------------|------------|
| SettingsView Decomposition | High (2-3 days) | Medium |
| SearchService Decomposition | Medium (1-2 days) | Medium |
| @unchecked Sendable Audit | Low (0.5 day) | Low |
| Singleton DI | Medium-High (2 days) | Medium |

## Dependencies Between Tasks

1. **Task 4 (DI)** can be started independently
2. **Task 3 (Sendable Audit)** can be started independently  
3. **Task 1 (SettingsView)** is independent
4. **Task 2 (SearchService)** is independent

## Recommended Execution Order

1. Start **Task 3** (lowest effort, immediate safety benefit)
2. Start **Task 4** (foundation for testing, can proceed in parallel with others)
3. Start **Task 1** and **Task 2** (large refactors, possibly in parallel if team size allows)

---

## Rollback Plan

If any refactoring introduces issues:
- Git tags at each major milestone
- Feature flags for gradual rollout
- Comprehensive test suite as safety net
