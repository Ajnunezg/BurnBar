# BurnBarOperatingLayer Refactor Plan

## Why This Needs a Plan

`AgentLens/Services/BurnBarOperatingLayer.swift` is 4103 lines and currently contains at least five separate layers:

- domain enums and snapshot types
- persistence record types
- the observable `BurnBarOperatingLayer` state machine
- a large composition engine (`BurnBarOperatingComposer`)
- setup-guide builders and a large amount of SwiftUI view code

This is not one service. It is a service, a composition engine, a view-model layer, and a UI component library fused into one file.

## Current Fault Lines

- `AgentLens/Services/BurnBarOperatingLayer.swift:4` through `:774` defines models and runtime snapshots.
- `AgentLens/Services/BurnBarOperatingLayer.swift:775` through `:797` defines persistence records.
- `AgentLens/Services/BurnBarOperatingLayer.swift:802` through `:1169` holds the observable layer and action methods.
- `AgentLens/Services/BurnBarOperatingLayer.swift:1171` through `:2504` holds the composer and builder logic.
- `AgentLens/Services/BurnBarOperatingLayer.swift:2505` through `:2708` holds setup-guide builders.
- `AgentLens/Services/BurnBarOperatingLayer.swift:2710` through `:4103` holds SwiftUI views and shared UI helpers.

That means any change to product logic currently churns the same file as dashboard rendering and menu bar UI.

## Non-Negotiables

- Keep the public `BurnBarOperatingLayer` type stable so app wiring and tests do not fan out.
- Do not change the meaning of `snapshot`, `actionFeedback`, or `controllerFeedback` while moving code.
- Do not mix service extraction and UI redesign in the same refactor.
- Each phase must compile without forcing the rest of the app to update imports or API shape.

## Target End State

The service side lives under `AgentLens/Services/BurnBarOperating/`:

- `BurnBarOperatingModels.swift`
- `BurnBarOperatingPersistenceTypes.swift`
- `BurnBarOperatingLayer.swift`
- `BurnBarOperatingLayer+MissionActions.swift`
- `BurnBarOperatingLayer+ControllerActions.swift`
- `BurnBarOperatingComposer.swift`
- `BurnBarSetupGuideBuilder.swift`

The UI side lives under `AgentLens/Views/Components/Operating/`:

- `BurnBarDashboardOperatingSection.swift`
- `BurnBarCompactOperatingHomeCard.swift`
- `BurnBarHermesOperatingStrip.swift`
- `BurnBarOperatingActionBar.swift`
- `BurnBarControllerWorkbenchPanel.swift`
- supporting card/subview files as needed

The rule is simple:

- services build snapshots
- views render snapshots
- the file that owns state does not also own 1000+ lines of SwiftUI

## Refactor Sequence

### Phase 0: Freeze the Surface Area

- Treat `BurnBarOperatingLayerTests` as the contract.
- Add a few more targeted tests if needed before moving code:
  - snapshot composition for a seeded project
  - mission approval and direction override mutations
  - controller mirror actions
  - rendering smoke tests for the three main operating views

Gate:

- `xcodebuild -scheme BurnBar -project BurnBar.xcodeproj -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO -only-testing:BurnBarTests/BurnBarOperatingLayerTests`

### Phase 1: Extract Models First

- Move the pure enums and structs out of `BurnBarOperatingLayer.swift` first.
- Start with:
  - operating availability, lifecycle, freshness, and action enums
  - snapshot and summary structs
  - controller runtime structs
  - persistence record structs

Why first:

- these types have the widest reuse
- they are the lowest-risk move
- this shrinks the main file immediately without changing behavior

Rules:

- do not rename types yet
- do not alter access levels more than necessary
- keep behavior-bearing computed properties with the type if they are purely local

### Phase 2: Split the Observable Layer From the Composer

- Move `BurnBarOperatingComposer` and all builder helpers into `BurnBarOperatingComposer.swift`.
- Keep `BurnBarOperatingLayer.snapshot` as the stable entry point.
- The layer should orchestrate dependencies; the composer should build the immutable snapshot.

After this phase, `BurnBarOperatingLayer` should mainly contain:

- injected dependencies
- revision and feedback state
- `snapshot`
- action methods

Critical rule:

- do not change the composer algorithm during the move
- if a builder helper is ugly, move it first and clean it later

### Phase 3: Split Action Methods Into Focused Extensions

- Move mission approval and direction override methods into `BurnBarOperatingLayer+MissionActions.swift`.
- Move controller runtime refresh / answer / snooze / complete / calendar methods into `BurnBarOperatingLayer+ControllerActions.swift`.
- Keep them as extensions on the same type so all current call sites keep working.

Why this is safer than inventing a new service immediately:

- those methods mutate `stateRevision`, `actionFeedback`, and `controllerFeedback`
- moving them into extensions reduces file size without introducing new ownership questions too early

### Phase 4: Extract Setup Guide Code

- Move `BurnBarSetupGuideSnapshot`, `BurnBarSetupGuideBuilder`, and the setup-guide cards out of the operating layer file.
- This logic is adjacent to the operating experience, but it is not part of the core layer or composer.

Suggested split:

- builder in services
- cards in views

### Phase 5: Move SwiftUI Out of Services

This is the biggest payoff and should happen after the model and composer moves.

Move the SwiftUI views in coherent clusters, not one tiny type at a time:

1. `BurnBarDashboardOperatingSection` plus its directly-owned cards
2. `BurnBarCompactOperatingHomeCard` plus compact helpers
3. `BurnBarHermesOperatingStrip` plus strip-specific helpers
4. `BurnBarControllerWorkbenchPanel` plus question/followup/history subviews
5. remaining shared chips, badges, and helper views

Rules:

- preserve initializer signatures while moving
- preserve `@Bindable var layer: BurnBarOperatingLayer` where it already exists
- do not redesign spacing, hierarchy, or copy in the extraction PRs

### Phase 6: Extract Shared UI Helpers Cleanly

At the bottom of the current file there are file-local helpers like:

- shared title/metric helpers
- small badge/chip views
- `String.nonEmpty` / array convenience helpers

Move them deliberately:

- UI-only helpers go near the view files
- reusable string/collection helpers go to a small shared utility file if they are used elsewhere

Do not leave these stranded in the service file after views move out.

## Suggested File Layout

Services:

- `AgentLens/Services/BurnBarOperating/BurnBarOperatingModels.swift`
- `AgentLens/Services/BurnBarOperating/BurnBarOperatingPersistenceTypes.swift`
- `AgentLens/Services/BurnBarOperating/BurnBarOperatingLayer.swift`
- `AgentLens/Services/BurnBarOperating/BurnBarOperatingLayer+MissionActions.swift`
- `AgentLens/Services/BurnBarOperating/BurnBarOperatingLayer+ControllerActions.swift`
- `AgentLens/Services/BurnBarOperating/BurnBarOperatingComposer.swift`
- `AgentLens/Services/BurnBarOperating/BurnBarSetupGuideBuilder.swift`

Views:

- `AgentLens/Views/Components/Operating/BurnBarDashboardOperatingSection.swift`
- `AgentLens/Views/Components/Operating/BurnBarCompactOperatingHomeCard.swift`
- `AgentLens/Views/Components/Operating/BurnBarHermesOperatingStrip.swift`
- `AgentLens/Views/Components/Operating/BurnBarControllerWorkbenchPanel.swift`
- `AgentLens/Views/Components/Operating/BurnBarOperatingSharedViews.swift`

## Safety Rails

- Freeze `BurnBarOperatingSnapshot` shape until extraction is done.
- Keep `snapshot` as the single read API during the whole refactor.
- If a view needs extra helpers after extraction, move the helper with that view instead of broadening access on service internals.
- Avoid converting `private` to `internal` unless the new file boundary requires it.
- Do not introduce protocols just to make the file smaller. Move code first, abstract only where reuse becomes real.

## Suggested PR Breakdown

1. `BurnBarOperating: extract models and persistence records`
2. `BurnBarOperating: extract composer and builders`
3. `BurnBarOperating: split mission and controller actions into extensions`
4. `BurnBarOperating UI: move dashboard and compact operating cards`
5. `BurnBarOperating UI: move workbench, strip, and shared helpers`

## Definition of Done

- `BurnBarOperatingLayer.swift` is a real service file, not a service-plus-UI bundle
- the composer and setup builder live outside the observable layer
- SwiftUI operating components live under `AgentLens/Views/Components/Operating/`
- `BurnBarOperatingLayerTests` still pass without broad API churn
- future product logic changes do not require touching the same file as dashboard rendering
