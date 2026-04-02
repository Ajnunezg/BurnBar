# Changelog

All notable changes to BurnBar are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `QUICKSTART.md` for new contributors
- `bug_report.md` issue template
- `feature_request.md` issue template
- `PULL_REQUEST_TEMPLATE.md` for contributors
- `BurnBarDaemonLogger.warning()` method for proper log level coverage
- public release scaffolding for support, security, and third-party notices

### Changed
- project versioning aligned on `0.1.0-beta` for the app, daemon, and extension
- README and quick start copy updated for experimental-source-release positioning
- public docs scrubbed to remove stale personal repository URLs and inaccurate storage/version claims

### Fixed
- TypeScript build error in `panelViewModel.ts` (`state.workspace` possibly undefined)
- TypeScript lint warnings (unused variables, missing defaults, empty methods)
- Silent error handling in `encodeErrorResponse()` with proper logging
- Swift `try?` in `BurnBarRunService.restorePersistedRunsIfNeeded()` replaced with explicit error handling
- Removed duplicate `CODEOWNERS` file (keeping `.github/CODEOWNERS`)
- Removed personal tool configuration from `tools/`
- Firebase credentials file removed from working tree
- broken public-doc links and missing implementation-support docs
- stale OpenRouter `HTTP-Referer` headers pointing at a private repository URL

### Security
- Dependabot configured for npm, Swift, and GitHub Actions dependency updates
- current `npm audit` status is limited to low-severity development-only findings

### Infrastructure
- GitHub Actions CI workflow for pull request validation
- GitHub Actions release workflow for tagged prereleases

---

## [Prior Releases]

Prior to this changelog, releases were tracked informally. The following milestones are documented in commit history:

- Initial macOS menu bar app (AgentLens → BurnBar)
- Claude Code parser and session log parsing
- Factory/Droid session parsing
- Codex SQLite log parsing
- Kimi session parsing
- Local daemon (JSON-RPC over UNIX socket)
- GRDB/SQLite storage layer with migrations
- Firebase Auth (Google + Apple Sign-In)
- Firestore cloud sync
- Projection pipeline (FTS5 + semantic search)
- VS Code / Cursor extension
- Cursor provider routing (Z.ai, MiniMax)
- CLI command interface
- Cloudflare tunnel support
- InsightEngine and analytics
- Daily digest notifications
- iCloud session file mirror
