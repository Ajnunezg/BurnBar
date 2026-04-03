# BurnBar Extension

BurnBar is a local-first sidebar companion for Cursor and VS Code. The extension talks to the BurnBar daemon on the same machine and surfaces daemon health, run state, and workspace-aware recovery guidance.

## Status

This extension is part of BurnBar's current **experimental source release**. It is intended for local development and early adopters rather than a polished marketplace install. There is no public VS Marketplace / Open VSX release or signed VSIX shipped from this repository today.

The repo metadata currently declares version `0.1.0-beta`. Create `v0.1.0-beta` as the first public git tag if you want public tag/version support language to match reality.

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

Current release model:

- build locally from this repository
- load through your editor's local development / unpacked-extension flow
- do not assume a public marketplace listing or packaged install path yet

## Repository

- Source: https://github.com/Ajnunezg/BurnBar
- Issues: https://github.com/Ajnunezg/BurnBar/issues

## Workspace trust

In restricted workspaces, the extension keeps read-only inspection features available and gates file-editing and terminal actions until the workspace is trusted.
