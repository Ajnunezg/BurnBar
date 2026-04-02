---
name: ChatSessionController lifting audit
description: Findings from the ChatSessionController lift into BurnBarApp — known issues and wiring patterns as of 2026-03-25
type: project
---

`ChatSessionController` is owned as `@State` in `BurnBarApp` (line 180) and passed by value to all call sites. It shares the same `DataStore` instance created in `init()`.

**Known issues found (2026-03-25):**

1. `AppCommandRouter.openChatPanel` is NEVER cleared on `onDisappear`. If the dashboard window is closed and the NSWindow (which is `isReleasedWhenClosed = false`) is re-shown, the old closure still refers to a potentially stale SwiftUI State capture. Low severity since there's only ever one DashboardView instance (WindowManager guards against re-creation), but it's a latent leak.

2. `AppCommandRouter.handle(_:)` maps the `"chat"` URL scheme target to `openConversationSearch?()` — NOT `openChatPanel?()`. So `burnbar://chat` opens the dashboard and fires a `burnBarOpenConversationSearch` notification rather than opening the ChatPanel overlay. This may or may not be intentional — both surfaces handle the same concept but differently.

3. `installCommandRouter()` is called from inside `@SceneBuilder` via `let _ = installCommandRouter()`. This is a side-effect injection inside a view builder — it re-runs on every scene rebuild. In practice it just re-assigns the same closures, so it's harmless but unconventional. Not a bug.

4. `openChatPanel` is NOT registered in `installCommandRouter()` — it's only set in `DashboardView.onAppear`. This means `AppCommandRouter.shared.openChatPanel` is nil until the dashboard window is opened. The `onOpenDashboardWithChat` closure in `MenuBarPopoverView` accounts for this with a 0.25s delay before calling it, but if the dashboard takes longer than 250ms to appear and register `onAppear`, the call silently does nothing.

5. Two separate `.onAppear` blocks on the same `body` view in `DashboardView` (lines 180 and 221). SwiftUI runs both; this is fine but slightly confusing.

**What IS correct:**
- `chatController` init uses same `store` instance as `_dataStore` — same DataStore.
- All `windowManager.openDashboard()` call sites pass `chatController`.
- `probeHermesAvailability` fired inside `.task` on `MenuBarLabel` — correct, runs after first frame.
- `MenuBarPopoverView` accepts `chatController` as `Optional` — correct, app always passes non-nil.
- `DashboardView.chatController` is a plain `var` (not `@State`) — correct, ownership stays in App.
- `#Preview` passes `chatController` correctly; `settingsManager` default param covers the missing arg.

**Why:** The `openChatPanel` nil-window race is the one actionable risk. 250ms is usually enough on fast Macs but may miss on first launch when the window is being constructed for the first time.

**How to apply:** When investigating chat panel open failures (panel doesn't appear after tapping Hermes strip in popover), check this timing gap first.
