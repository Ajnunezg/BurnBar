# Navigation Modernization Implementation Plan

## Objective

Replace `NotificationCenter` usage with a modern SwiftUI `@Environment` approach for navigation coordination.

## Implementation Plan

### Task 1: Create NavigationCoordinator
- [ ] Create `AgentLens/Services/NavigationCoordinator.swift`
- [ ] Define `NavigationDestination` enum for app destinations
- [ ] Implement `@Observable` coordinator class
- [ ] Add methods to trigger navigation

### Task 2: Update AgentLensApp.swift
- [ ] Remove `Notification.Name` extension (lines 6-9)
- [ ] Remove `NotificationCenter.default.post` calls (lines 320, 359)
- [ ] Remove `DispatchQueue.main.asyncAfter` delays (lines 319, 358, 382)
- [ ] Initialize and inject `NavigationCoordinator` via environment

### Task 3: Update DashboardView.swift
- [ ] Add `@Environment(NavigationCoordinator.self)` property
- [ ] Replace `onReceive(NotificationCenter.publisher)` with coordinator observation
- [ ] Remove `.onAppear` for AppCommandRouter.openChatPanel setup

### Task 4: Update AppCommandRouter
- [ ] Remove `openChatPanel` closure (only used for notification)
- [ ] Update remaining router usages if any

### Task 5: Verify Build
- [ ] Run xcodebuild to verify compilation
- [ ] Fix any compilation errors

## Verification Criteria

1. Build succeeds without warnings
2. Navigation still works after opening dashboard from menu bar
3. Conversation search opens when triggered from menu bar
4. Missions tab opens when triggered from menu bar

## Files to Modify

1. `AgentLens/Services/NavigationCoordinator.swift` (new)
2. `AgentLens/App/AgentLensApp.swift`
3. `AgentLens/Views/Dashboard/DashboardView.swift`
