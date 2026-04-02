---
name: HermesToolCard audit findings
description: Known issues and fragile areas in HermesToolCard.swift found during March 2026 audit
type: project
---

The shimmer dot pulse animation fires only once (onAppear sets pulse=true, never resets to false), making the `repeatForever` animation orphaned after the view identity changes (e.g. tool name changes mid-stream). The dot also leaks its `pulse` @State across isRunning=false→true transitions because onChange only resets isExpanded, not pulse.

The private ChatBubbleStyle enum in HermesToolCard is a verbatim copy of the one in ChatMessageView.swift. Both currently agree, but they are not linked — a corner-radius tweak in ChatMessageView won't propagate here.

The capability icon mapping covers 8 surface-level categories via substring matching. No coverage for: mcp, tool_search, notebook, diff, deploy, git, sql/database, api, config, or any Hermes-specific tool names (task_complete, computer_use, etc.). Falls through to wrench fallback for all of these.

The `.clipShape(shape)` and `.overlay(shape.strokeBorder(...))` use a stored `let shape` property initialized at struct init time. UnevenRoundedRectangle is a value type so this is safe — no identity issue here.

The `isRunning` onChange handler (line 91-97) resets isExpanded to false when a tool finishes. This is intentional progressive disclosure reset but could feel jarring if the user had manually expanded a completed card.

**Why:** Recorded during targeted audit of HermesToolCard.swift requested on 2026-03-25.
**How to apply:** Reference when investigating animation bugs, shape divergence, or icon coverage gaps in the chat tool card layer.
