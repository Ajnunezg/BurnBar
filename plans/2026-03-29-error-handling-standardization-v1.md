# Error Handling Standardization Plan

## Objective

Standardize error handling across the codebase to improve debuggability while maintaining appropriate fail-safe behavior.

## Error Handling Taxonomy

### Category 1: Silent Failures (Acceptable)
These operations can safely fail silently:
- `Task.sleep(nanoseconds:)` - Timer failures don't affect UX
- `handle.close()` - File handle cleanup failures
- `JSONDecoder` fallbacks for optional fields
- Regex compilation with `guard let regex = try? NSRegularExpression`

### Category 2: Silent Failures (Needs Logging)
These operations should log failures for debugging:
- **Data persistence**: `saveChatMessage()`, `upsertDevice()`, `upsertConversation()`
- **Data retrieval**: `fetchChatMessages()`, `fetchChatThreadSummaries()`
- **File operations**: `createDirectory()`, `removeItem()`
- **Cloud sync**: All sync operations

### Category 3: Never Silent
These must never fail silently:
- Authentication operations
- Database initialization
- Migration failures
- Critical path operations (the app cannot function)

---

## Implementation Plan

### Task 1: Create AgentLens Logger
- [ ] Create `AgentLens/Services/Logger.swift`
- [ ] Mirror `BurnBarDaemonLogger` pattern
- [ ] Add app-specific categories
- [ ] Support debug/release logging levels

### Task 2: Add Logging to Critical Silent Failures

**ChatSessionController.swift (~15 locations)**
- [ ] `saveChatMessage()` calls at lines 513, 529, 544, 556, 567, 578, 642
- [ ] `fetchChatMessages()` calls at lines 208, 346, 399
- [ ] `createChatThread()` calls at lines 319, 326, 373
- [ ] `fetchChatThreadSummaries()` at line 382
- [ ] `findConversationFullTextMatches()` at line 886

**SettingsView.swift (~10 locations)**
- [ ] `fetchEmbeddingModels()` at line 944
- [ ] `fetchEmbeddingVersions()` at line 945
- [ ] `countSearchDocuments()` at line 996
- [ ] `countSearchChunks()` at line 1000
- [ ] `countChunkEmbeddings()` at line 1004
- [ ] `fetchConversationsNeedingSummary()` at line 2353
- [ ] `upsertDevice()` at line 4608
- [ ] `fetchDevices()` at line 4588

### Task 3: Verify Build
- [ ] Run xcodebuild to verify compilation
- [ ] Fix any compilation errors

---

## Files to Modify

1. `AgentLens/Services/Logger.swift` (new)
2. `AgentLens/Views/Chat/ChatSessionController.swift`
3. `AgentLens/Views/Settings/SettingsView.swift`

## Verification Criteria

1. All critical data operations have error logging
2. Build succeeds without warnings
3. No regression in functionality
