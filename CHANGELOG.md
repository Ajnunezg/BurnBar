# Changelog

All notable changes to BurnBar are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `QUICKSTART.md` for new contributors
- `BUG_REPORT.yml` issue template
- `FEATURE_REQUEST.yml` issue template
- `PULL_REQUEST_TEMPLATE.md` for contributors
- `BurnBarDaemonLogger.warning()` method for proper log level coverage

### Changed
- Version updated to `0.1.0-beta` (from `1.0.0`)
- README updated with beta status

### Fixed
- TypeScript build error in `panelViewModel.ts` (`state.workspace` possibly undefined)
- TypeScript lint warnings (unused variables, missing defaults, empty methods)
- Silent error handling in `encodeErrorResponse()` with proper logging
- Swift `try?` in `BurnBarRunService.restorePersistedRunsIfNeeded()` replaced with explicit error handling
- npm mocha vulnerability (GHSA-5c6j-r48x-rmvq, GHSA-73rr-hh4g-fpgx) resolved by upgrading to mocha@11
- Removed duplicate `CODEOWNERS` file (keeping `.github/CODEOWNERS`)
- Removed personal tool configuration from `tools/`
- Firebase credentials file removed from working tree

### Security
- Dependabot configured for npm, Swift, and GitHub Actions dependency updates

### Infrastructure
- GitHub Actions CI workflow for pull request validation
- Branch protection and CODEOWNERS for review discipline

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
