# BurnBar Implementation Checklist

This checklist is the public companion to the Cursor agent spec. It is intentionally high-level and avoids private planning or maintainer-only prompts.

## Foundation

- Keep `BurnBarCore` as the shared home for RPC contracts, catalog metadata, and run-state types.
- Keep the daemon as the single source of truth for run state, approvals, and provider routing.
- Keep the extension responsible for editor UX and workspace capability detection.

## Daemon

- Health endpoint responds over the Unix domain socket.
- Provider configuration and secrets resolve without embedding credentials in the extension.
- Run lifecycle supports start, retry, cancel, and approval states.
- Usage events are recorded durably enough to survive daemon restarts.

## App

- App can install, repair, and inspect the local daemon.
- Settings expose provider configuration, cloud options, and daemon health clearly.
- Local-first behavior remains the default when optional cloud features are disabled.

## Extension

- Sidebar remains usable in untrusted workspaces with safe read-only degradation.
- Workspace companion behavior is explicit for local, remote, read-only, and virtual workspaces.
- Repair/reconnect paths work without requiring private maintainer knowledge.

## Verification

- Swift package tests pass for `BurnBarCore` and `BurnBarDaemon`.
- Extension unit tests and extension-host tests pass.
- Retrieval replay evals pass.
- Public docs match the current shipped behavior.
