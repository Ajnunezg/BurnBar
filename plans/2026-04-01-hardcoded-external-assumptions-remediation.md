# Remediation Plan: Hardcoded External Assumptions (Pricing, Schemas)

**Date:** 2026-04-01
**Status:** Planning
**Priority:** High

---

## 1. Problem Statement

The codebase contains hardcoded external assumptions in three main categories:

1. **Pricing Data** - Model pricing hardcoded in `BurnBarCatalog.swift:264-458` and `catalog.json`
2. **Provider Base URLs** - API endpoints hardcoded in multiple locations
3. **Schema Assumptions** - JSON schema and API contract assumptions embedded in code

### 1.1 Specific Locations

| Category | Location | Issue |
|----------|----------|-------|
| Pricing | `BurnBarCore/Sources/BurnBarCore/BurnBarCatalog.swift:264-458` | 150+ lines of hardcoded pricing in `fallbackCatalog` |
| Pricing | `BurnBarCore/Resources/catalog.json` | 1700+ lines of bundled pricing (stale by nature) |
| Base URLs | `BurnBarCatalog.swift:427,435,443,451` | Hardcoded provider endpoints |
| Base URLs | `catalog.json:7,228,809,etc.` | 12+ hardcoded base URLs |
| Base URLs | `AgentLens/Services/ProviderUsageAPI/AnthropicUsageAPI.swift:13` | `https://api.anthropic.com/v1/organizations` |
| Base URLs | `AgentLens/Services/ProviderUsageAPI/OpenAIUsageAPI.swift:13` | `https://api.openai.com/v1/organization` |
| Base URLs | `AgentLens/Services/SearchService.swift:699` | Default OpenAI URL |
| Base URLs | `BurnBarDaemon/BurnBarToolPlaneService.swift:436-446` | GitHub, Slack, Linear, etc. defaults |
| Schema | `BurnBarCore/Sources/BurnBarCore/BurnBarContracts.swift` | Hardcoded API contract assumptions |

---

## 2. Root Cause Analysis

### 2.1 Why This Is a Problem

1. **Stale Pricing** - AI provider pricing changes frequently (weekly/monthly). Hardcoded prices become inaccurate, leading to incorrect cost tracking.

2. **API Endpoint Changes** - Providers occasionally change API endpoints (e.g., OpenAI v1 migration). Hardcoded URLs break integrations.

3. **New Models** - New AI models are released constantly. Each release requires a code change to update the catalog.

4. **Release Dependency** - Users must wait for a new app release to get updated pricing/URLs.

5. **Testing Difficulty** - Hardcoded values make it difficult to test against different environments (staging, mock servers, etc.).

### 2.2 Current Mitigations

The codebase has partial mitigations:
- `BurnBarCatalogLoader.bundledCatalog` uses `catalog.json` (externalizable)
- Fallback catalog exists for graceful degradation
- Catalog loading is lazy and can be replaced at runtime

---

## 3. Remediation Options

### Option A: Remote Catalog with Local Fallback (Recommended)

**Approach:**
1. Add a `RemoteCatalogService` that fetches catalog from a CDN/GitHub releases
2. Cache catalog locally with timestamp
3. Use bundled catalog as fallback for offline/air-gapped environments
4. Background refresh on configurable interval

**Pros:**
- Automatic updates without app release
- Air-gapped fallback maintained
- Easy rollback if bad catalog deployed

**Cons:**
- Requires network access for updates
- CDN hosting cost/maintenance
- Potential for stale cached data if refresh fails

### Option B: Configurable Provider Endpoints

**Approach:**
1. Move base URLs to `BurnBarProviderSettings` in user configuration
2. Allow users to override default endpoints
3. Support environment-based configuration

**Pros:**
- User control over endpoints
- Easy to support proxies/self-hosted

**Cons:**
- Users may misconfigure
- More configuration burden
- Doesn't solve pricing updates

### Option C: Catalog Version + Manual Update

**Approach:**
1. Add version checking against bundled catalog
2. Prompt users to update when new version available
3. Store catalog in user-writable directory
4. Provide update mechanism (download, import)

**Pros:**
- User consent for updates
- No automatic network access

**Cons:**
- Manual process, users may not update
- Still requires app release for update mechanism

---

## 4. Recommended Implementation Plan

### Phase 1: Extract URLs to Configuration (Low Risk)

**Files to modify:**
- [ ] `BurnBarCatalog.swift` - Extract base URLs to constants
- [ ] `AgentLens/Services/ProviderUsageAPI/AnthropicUsageAPI.swift`
- [ ] `AgentLens/Services/ProviderUsageAPI/OpenAIUsageAPI.swift`
- [ ] `BurnBarDaemon/BurnBarToolPlaneService.swift`

**Tasks:**
- [ ] Create `ProviderEndpoints.swift` with URL constants
- [ ] Update all hardcoded URLs to use constants
- [ ] Add `ProviderEndpoint` struct for runtime configuration
- [ ] Update tests to use configurable endpoints

### Phase 2: Add Remote Catalog Service (Medium Risk)

**New files:**
- [ ] `BurnBarCore/Sources/BurnBarCore/Catalog/CatalogUpdateService.swift`
- [ ] `BurnBarCore/Sources/BurnBarCore/Catalog/CatalogCache.swift`
- [ ] `BurnBarCore/Sources/BurnBarCore/Catalog/CatalogSource.swift` (protocol)

**Tasks:**
- [ ] Define `CatalogSource` protocol for pluggable catalog providers
- [ ] Implement `BundledCatalogSource` (existing behavior)
- [ ] Implement `RemoteCatalogSource` for HTTP fetching
- [ ] Implement `CachedCatalogSource` with TTL
- [ ] Add catalog signature validation (security)
- [ ] Write unit tests for catalog loading

### Phase 3: User Configuration Override (Medium Risk)

**Files to modify:**
- [ ] `BurnBarDaemon/Sources/BurnBarDaemon/BurnBarConfigStore.swift`
- [ ] `AgentLens/Services/Settings/SettingsStore.swift`

**Tasks:**
- [ ] Add `customCatalogURL` to user settings
- [ ] Add `customProviderEndpoints` map
- [ ] Create UI for catalog source selection
- [ ] Validate custom catalog before use

### Phase 4: Pricing Override API (Low Risk)

**Files to modify:**
- [ ] `BurnBarCore/Sources/BurnBarCore/BurnBarCatalog.swift`

**Tasks:**
- [ ] Add `overridePricing(forModel:pricing:)` method
- [ ] Add `overridePricingProvider` for user-defined prices
- [ ] Merge user overrides with catalog prices
- [ ] Persist overrides in user config

---

## 5. Detailed Tasks

### Task 1.1: Create ProviderEndpoints.swift

```swift
// BurnBarCore/Sources/BurnBarCore/ProviderEndpoints.swift

public struct ProviderEndpoints {
    public static let anthropic = URL(string: "https://api.anthropic.com")!
    public static let openAI = URL(string: "https://api.openai.com")!
    // ... etc

    public struct V1 {
        public static let anthropic = URL(string: "https://api.anthropic.com/v1")!
        public static let openAI = URL(string: "https://api.openai.com/v1")!
    }
}
```

### Task 1.2: Update Provider Usage APIs

```swift
// AgentLens/Services/ProviderUsageAPI/AnthropicUsageAPI.swift
// Before:
private let baseURL = "https://api.anthropic.com/v1/organizations"

// After:
private let baseURL: URL
init(baseURL: URL = ProviderEndpoints.V1.anthropicOrganization)
```

### Task 2.1: Define CatalogSource Protocol

```swift
// BurnBarCore/Sources/BurnBarCore/Catalog/CatalogSource.swift

public protocol CatalogSource {
    var sourceName: String { get }
    func loadCatalog() async throws -> BurnBarCatalog
    var lastModified: Date? { get }
}

public enum CatalogSourcePriority {
    case local   // User config
    case remote  // CDN/fetched
    case bundled // Fallback
}
```

### Task 2.2: Implement RemoteCatalogSource

```swift
// BurnBarCore/Sources/BurnBarCore/Catalog/RemoteCatalogSource.swift

public struct RemoteCatalogSource: CatalogSource {
    public let url: URL
    public let signatureKey: Data? // Optional HMAC validation
    public let refreshInterval: TimeInterval

    public func loadCatalog() async throws -> BurnBarCatalog {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw CatalogSourceError.fetchFailed
        }
        return try BurnBarCatalogLoader.decode(data)
    }
}
```

### Task 3.1: Add User Configuration

```swift
// BurnBarDaemon/Sources/BurnBarDaemon/BurnBarConfigStore.swift

public struct CatalogConfiguration: Codable {
    public var source: CatalogSourceType = .bundled
    public var remoteURL: URL?
    public var customPricingOverrides: [String: BurnBarModelPricing] = [:]
    public var customEndpoints: [String: String] = [:] // providerID -> URL
}

public enum CatalogSourceType: String, Codable {
    case bundled
    case remote
    case local
}
```

---

## 6. Testing Strategy

### 6.1 Unit Tests

- [ ] `CatalogSource` protocol tests
- [ ] `BundledCatalogSource` tests
- [ ] `RemoteCatalogSource` tests (mock server)
- [ ] `CachedCatalogSource` tests
- [ ] Catalog merge/override tests

### 6.2 Integration Tests

- [ ] End-to-end catalog update flow
- [ ] Offline fallback behavior
- [ ] User override persistence

### 6.3 Manual Testing

- [ ] Air-gapped environment (no network)
- [ ] Invalid catalog handling
- [ ] Catalog rollback scenario

---

## 7. Security Considerations

### 7.1 Catalog Integrity

- [ ] Add SHA256 signature to catalog JSON
- [ ] Validate signature before loading
- [ ] Reject catalogs with invalid signatures
- [ ] Log all catalog source changes

### 7.2 Endpoint Validation

- [ ] Validate custom URLs are HTTPS (except localhost)
- [ ] Sanitize user-provided endpoints
- [ ] Prevent SSRF via URL validation

### 7.3 Privacy

- [ ] No analytics on catalog updates (opt-in only)
- [ ] Catalog cache is local-only
- [ ] Custom pricing overrides are encrypted at rest

---

## 8. Rollback Plan

If remote catalog deployment fails:

1. **Immediate:** Users can switch to `bundled` source in settings
2. **Short-term:** Deploy fixed catalog to CDN
3. **Long-term:** Add catalog versioning with rollback

---

## 9. Milestones

| Milestone | Description | Estimated Time |
|-----------|-------------|----------------|
| M1 | Extract URLs to constants | 1 day |
| M2 | Implement CatalogSource protocol | 2 days |
| M3 | Add RemoteCatalogSource | 2 days |
| M4 | Add caching layer | 1 day |
| M5 | User configuration UI | 2 days |
| M6 | Security hardening | 1 day |
| M7 | Testing & documentation | 2 days |

**Total:** ~11 days

---

## 10. Success Criteria

- [ ] All hardcoded URLs replaced with constants or configuration
- [ ] Remote catalog can be loaded without app release
- [ ] Air-gapped mode still works with bundled catalog
- [ ] User can override pricing for custom models
- [ ] Catalog integrity validated via signature
- [ ] All new code has unit test coverage >80%
- [ ] Documentation updated for new configuration options
