# BurnBar Subagent Prompts

These prompts are sanitized public templates for parallel implementation work. Treat them as starting points, not source-of-truth architecture documents.

## Foundation Worker

Focus on shared contracts and schema surfaces only.

- Own changes in `BurnBarCore/`.
- Avoid app UI, daemon lifecycle, and extension manifest edits unless explicitly assigned.
- Preserve backward compatibility where feasible and call out any protocol/schema break.

## Daemon Worker

Focus on daemon-only execution and control-plane behavior.

- Own changes in `BurnBarDaemon/`.
- Do not change extension manifest or shared contract files without coordination.
- Prefer durable state transitions, explicit errors, and restart-safe behavior.

## Extension Worker

Focus on `extensions/burnbar/`.

- Preserve workspace-trust and restricted-workspace behavior.
- Keep daemon repair/reconnect flows understandable to first-time users.
- Avoid embedding provider credentials or assuming local-only workspace semantics.

## App Worker

Focus on `AgentLens/` app surfaces.

- Keep the app a client of daemon-owned runtime state.
- Preserve local-first behavior and honest degraded-mode UX.
- Avoid hidden coupling to private maintainer setup.

## Integration Rules

- Assign one owner per shared contract surface.
- Prefer disjoint write scopes.
- Merge in waves, not all at once.
- Re-run repo-native tests after each converged wave.
