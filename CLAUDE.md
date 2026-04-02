# BurnBar

Native macOS menu bar app tracking AI agent token usage and cost. SwiftUI + GRDB/SQLite. Menu bar popover + floating dashboard + settings window.

## Design System

Always read `DESIGN.md` before making any visual or UI decisions. All font choices, colors, spacing, and aesthetic direction are defined there. Do not deviate without explicit user approval. In QA mode, flag any code that doesn't match DESIGN.md.

Key rules:
- **Typography:** SF Pro Rounded everywhere (`Font.system(..., design: .rounded)`). No other fonts.
- **Colors:** All colors must be adaptive (light/dark) via `Color.adaptive(light:dark:)` in `ColorAdaptive.swift`. Never use hardcoded colors outside DesignSystem.
- **Spacing:** Base unit 4px. Use `DesignSystem.Spacing` tokens, not raw values.
- **Animation:** Always use `animation(_:value:)` — never `animation(_:)` without a value parameter.
- **Section headers:** `caption` (12pt) + `semibold` + `textSecondary`. Never `tiny` + `textMuted`.

## Hermes Integration

BurnBar is evolving from a spend tracker into an agent command center via Hermes Agent (NousResearch).

- **Hermes is already a fully wired provider** — `AgentProvider.hermes`, `HermesParser`, colors (#A855F7/#C084FC), all registered.
- **Chat identity uses mercury colors** (hermesMercury/hermesAureate), NOT provider purple. See DESIGN.md "Hermes Mercury" section.
- **Two chat surfaces:** popover Hermes strip (compact) + dashboard chat panel (full, with mode toggle).
- **Backend:** Hermes gateway API on localhost:8642 (`API_SERVER_ENABLED` in ~/.hermes/.env, `hermes gateway run`). Optional `API_SERVER_KEY` in that file → same value in BurnBar Settings if set. OpenAI-compatible, SSE streaming. Falls back to existing CLI bridge.
- **Tool cards:** Collapsible, progressive disclosure, mercury gradient strokes. Group by capability, never enumerate all 40+ tools.
- **Thinking state:** Mercury pooling droplets, not a spinner.

## Architecture

- **App entry:** `AgentLensApp.swift` — single `MenuBarExtra` scene, no Dock icon (LSUIElement).
- **Data:** GRDB/SQLite. `DataStore.swift` owns schema + migrations. Daemon opens read-only.
- **Parsers:** Conform to `LogParser` protocol. Register in `UsageAggregator.init()`. One line to add a provider.
- **Chat:** `ChatSessionController` coordinates chat. `CLIBridge` manages subprocess/API backends. `CLIChatStreamEvent` (.text, .toolUse) is the streaming protocol.
- **Retrieval:** Hybrid lexical (FTS5) + semantic (brute-force cosine). `SearchService` → `ProjectionPipelineService` → `search_chunks` + `chunk_embeddings`.
- **Theme:** `DesignSystem.swift` has all tokens. `ProviderTheme.swift` maps providers to colors. `ColorAdaptive.swift` isolates AppKit import.

## Code Conventions

- The Xcode project folder is `AgentLens/` (historical name). Product name is **BurnBar**. Bundle ID: `com.burnbar.app`.
- Provider colors: add to all three switches in DesignSystem (`primary`, `accent`, `chartPalette`).
- All parsers must be `Sendable`. Return `[]` on missing files — never throw on absent log directories.
- Glass card pattern: `surface` bg + `border` stroke 0.5pt + `lg` corner radius. See `GlassCard` in `MenuBarPopoverView.swift`.
- Chat bubbles use `UnevenRoundedRectangle` with distinct shapes per role (user/assistant/tool). See `ChatBubbleStyle`.
