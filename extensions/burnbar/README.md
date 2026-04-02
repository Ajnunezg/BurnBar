# BurnBar Extension

BurnBar is a local-first sidebar companion for Cursor and VS Code. The extension talks to the BurnBar daemon on the same machine and surfaces daemon health, run state, and workspace-aware recovery guidance.

## Status

This extension is part of BurnBar's current **beta** source release. It is intended for local development and early adopters rather than marketplace-style installation.

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

The public package includes only the runtime bundle, media assets, and package metadata. Source and test files stay in the repository but are not part of the publish artifact.

## Workspace trust

In restricted workspaces, the extension keeps read-only inspection features available and gates file-editing and terminal actions until the workspace is trusted.
