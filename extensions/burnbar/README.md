# BurnBar Extension

BurnBar is a local-first sidebar companion for Cursor and VS Code. The extension talks to the BurnBar daemon on the same machine and surfaces daemon health, run state, and workspace-aware recovery guidance.

## Status

This extension is part of BurnBar's current **experimental source release**. It is intended for local development and early adopters rather than a polished marketplace install.

## Build

```bash
npm install
npm run build
```

## Test

```bash
npm run test:unit
npm run test:extension-host
```

## Packaging

The publish artifact is intentionally minimal: compiled runtime files under `dist/`, media assets, and package metadata.

## Workspace trust

In restricted workspaces, the extension keeps read-only inspection features available and gates file-editing and terminal actions until the workspace is trusted.
