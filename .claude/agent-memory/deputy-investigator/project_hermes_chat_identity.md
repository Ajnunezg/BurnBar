---
name: Hermes chat identity and mercury color system
description: Key facts about the Hermes chat variant in ChatMessageView — color tokens, glyph bugs, and IPC-adjacent identity propagation
type: project
---

Hermes chat identity uses `hermesMercury` / `hermesAureate` colors, NOT provider purple (#A855F7/#C084FC). `mercuryGradient` is a `LinearGradient` over those two tokens.

Known bug (as of 2026-03-25): The via badge caduceus glyph in `ChatMessageView` uses U+2642 (♂, MALE SIGN) instead of a true caduceus. This is a wrong Unicode codepoint.

`isHermes` is propagated from `msg.cliUsed == "hermes"` at the `ChatPanel` call site. The `showViaBadge` guard is `msg.cliUsed != nil`, so these two flags are tightly coupled but not identical — non-hermes badges still exist.

`isRunning` on `HermesToolCard` uses: `isStreaming && piece.id == transcript.last?.id && transcript.last?.kind == .toolUse`. This is correct for the "last piece is a tool" case but will NOT show running state for a tool that is mid-stream while a later text piece has already arrived.

**Why:** Hermes integration was added as a new chat variant layered onto the existing Index/CLI chat surface. Mercury identity was kept separate from provider purple to avoid visual collision.

**How to apply:** Always check `cliUsed == "hermes"` (string equality) as the Hermes gate. Never conflate with provider color tokens.
