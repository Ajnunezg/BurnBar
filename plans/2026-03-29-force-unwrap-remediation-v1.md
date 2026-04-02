# Force Unwrap Remediation Plan

## Objective

Replace 5 force unwraps (`try!`) in production code with proper error handling to prevent runtime crashes.

---

## Production `try!` Locations to Remediate

### 1. DataStore.swift:1114-1117 - Convenience Initializer

**Risk Level:** Critical  
**Impact:** App crashes on first launch if directory creation or database initialization fails

```swift
// CURRENT (lines 1113-1118)
convenience init() {
    let appDir = try! BurnBarMigration.prepareSupportDirectory()
    let dbPath = appDir.appendingPathComponent(BurnBarIdentity.databaseFileName).path
    let queue = try! DatabaseQueue(path: dbPath)
    try! self.init(databaseQueue: queue)
}
```

**Proposed Fix:** Change to throwing initializer that propagates errors

```swift
// TARGET
convenience init() throws {
    let appDir = try BurnBarMigration.prepareSupportDirectory()
    let dbPath = appDir.appendingPathComponent(BurnBarIdentity.databaseFileName).path
    let queue = try DatabaseQueue(path: dbPath)
    try self.init(databaseQueue: queue)
}
```

**Callers to Update:**
- `AgentLens/App/AgentLensApp.swift:224-233` - `dataStore` property initialization

---

### 2. DataStore.swift:3273-3278 - Credential Exposure Regexes (Static Property)

**Risk Level:** High  
**Impact:** App crashes at launch if any regex pattern is invalid (user-input patterns should never crash app)

**Current Issue:** These regexes contain user-supplied patterns from settings, making them crash-prone.

```swift
// CURRENT (lines 3272-3279)
private static let credentialExposureRegexes: [NSRegularExpression] = [
    try! NSRegularExpression(
        pattern: #"(?i)\b[A-Z0-9_]*(?:API[_-]?KEY|ACCESS[_-]?TOKEN|TOKEN|SECRET|PASSWORD)\b\s*[:=]\s*["']?[A-Za-z0-9_\-./+=]{8,}"#
    ),
    try! NSRegularExpression(pattern: #"\bsk-[A-Za-z0-9]{16,}\b"#),
    try! NSRegularExpression(pattern: #"\bAIza[0-9A-Za-z\-_]{16,}\b"#),
    try! NSRegularExpression(pattern: #"\bgh[pousr]_[A-Za-z0-9]{20,}\b"#)
]
```

**Proposed Fix:** Use lazy static property with proper error handling

```swift
// TARGET
private static lazy var credentialExposureRegexes: [NSRegularExpression]? = {
    let patterns = [
        #"(?i)\b[A-Z0-9_]*(?:API[_-]?KEY|ACCESS[_-]?TOKEN|TOKEN|SECRET|PASSWORD)\b\s*[:=]\s*["']?[A-Za-z0-9_\-./+=]{8,}"#,
        #"\bsk-[A-Za-z0-9]{16,}\b"#,
        #"\bAIza[0-9A-Za-z\-_]{16,}\b"#,
        #"\bgh[pousr]_[A-Za-z0-9]{20,}\b"#
    ]
    return patterns.compactMap { try? NSRegularExpression(pattern: $0) }
}()

private static func checkCredentialExposure(in text: String) -> [CredentialExposureResult] {
    guard let regexes = credentialExposureRegexes else { return [] }
    // ... existing logic using regexes
}
```

---

### 3. ProjectionPipelineService.swift:169 - OpenAI Provider Fallback

**Risk Level:** High  
**Impact:** Crashes if OpenAI model name validation fails unexpectedly

```swift
// CURRENT (lines 161-176)
case .openai:
    do {
        return try OpenAIEmbeddingProvider(
            apiKey: providerAPIKeyStore.apiKey(for: "openai") ?? "",
            modelName: settingsManager.indexOpenAIModel,
            versionTag: "openai-index-v1",
            chunkerVersion: ProjectionIdentity.chunkerVersion
        )
    } catch {
        return try! OpenAIEmbeddingProvider(  // ← Redundant try! inside catch
            apiKey: providerAPIKeyStore.apiKey(for: "openai") ?? "",
            modelName: "text-embedding-3-small",
            versionTag: "openai-index-v1",
            chunkerVersion: ProjectionIdentity.chunkerVersion
        )
    }
```

**Analysis:** This is a fallback to a known-good model. If the fallback fails, something is fundamentally wrong.

**Proposed Fix:** Return `nil` or `DeterministicFakeEmbeddingProvider()` as last resort

```swift
// TARGET
case .openai:
    do {
        return try OpenAIEmbeddingProvider(
            apiKey: providerAPIKeyStore.apiKey(for: "openai") ?? "",
            modelName: settingsManager.indexOpenAIModel,
            versionTag: "openai-index-v1",
            chunkerVersion: ProjectionIdentity.chunkerVersion
        )
    } catch {
        // Fallback to known-safe default; log for diagnostics
        do {
            return try OpenAIEmbeddingProvider(
                apiKey: providerAPIKeyStore.apiKey(for: "openai") ?? "",
                modelName: "text-embedding-3-small",
                versionTag: "openai-index-v1",
                chunkerVersion: ProjectionIdentity.chunkerVersion
            )
        } catch {
            // Return deterministic provider as last resort to prevent crash
            print("Projection: All OpenAI providers failed, using deterministic fallback: \(error)")
            return DeterministicFakeEmbeddingProvider()
        }
    }
```

---

## Files NOT Requiring Changes

### Test Files (Excluded from remediation)
- `AgentLensTests/AgentLensTests.swift:4957-4958` - Test code can use `try!` safely

### Good Examples Already in Codebase
- `BurnBarSearchPlanner.swift:838, 849` - Uses `guard let regex = try? NSRegularExpression...`
- `BurnBarToolPlaneService.swift:904` - Uses `guard let regex = try? NSRegularExpression...`
- `BurnBarPlannerService.swift:280, 297, 313, 335` - Uses `guard let regex = try? NSRegularExpression...`
- `ProjectionPipelineService.swift:1160` - Uses `guard let regex = try? NSRegularExpression...`

---

## Implementation Checklist

- [ ] Task 1: Update `DataStore.convenience init()` to throw, propagating errors properly
- [ ] Task 2: Update `AgentLensApp.swift` to handle throwing DataStore initialization
- [ ] Task 3: Refactor `credentialExposureRegexes` to use lazy initialization with optional
- [ ] Task 4: Fix `ProjectionPipelineService.swift:169` with proper fallback chain
- [ ] Task 5: Add error logging for diagnostic purposes
- [ ] Task 6: Verify all callers of `DataStore()` are updated

---

## Verification Criteria

1. App launches without crashing even if:
   - Support directory cannot be created
   - Database file cannot be opened
   - User settings contain invalid regex patterns

2. All `try!` occurrences in production code are eliminated (test code excluded)

3. Errors are logged for debugging without crashing

4. Graceful degradation occurs (e.g., deterministic embeddings instead of OpenAI)

---

## Alternative Approaches Considered

### Approach 1: Result Type (Rejected)
Use `Result<DataStore, Error>` instead of throwing.  
Trade-off: More verbose, less idiomatic Swift for initializers.

### Approach 2: Default Values (Rejected)
Return a mock/in-memory DataStore on failure.  
Trade-off: Data loss unacceptable; must fail loudly.

### Approach 3: Global Error Handler (Rejected)
Catch all errors in main.swift.  
Trade-off: Hides the real problem; violates fail-fast principle.

**Chosen:** Approach is to throw and propagate, with graceful fallbacks where appropriate.
