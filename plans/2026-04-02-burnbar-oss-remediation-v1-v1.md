# BurnBar Open-Source Remediation Plan v1

**Target:** 8.5 - 9.0 / 10 Open-Source Readiness  
**Current:** 6.5 / 10  
**Date:** 2026-04-02  
**Status:** Planning

---

## Executive Summary

This plan addresses all blocking and high-priority findings from the open-source readiness assessment to achieve 8.5-9.0 readiness. The approach is incremental and testable, with each phase building on the previous.

**Key improvements needed:**
1. Fix TypeScript build failure (blocking extension distribution)
2. Address silent error handling (try? patterns)
3. Complete community health files
4. Clean up personal/internal references
5. Resolve npm audit vulnerabilities
6. Polish release engineering

---

## Phase 1: Critical Blockers (Day 1)

### 1.1 Fix TypeScript Build Failure

**Impact:** Blocks extension publication  
**Current Score Improvement:** +1.0 (Packaging: 5→7)

| Task | Description | Files | Effort |
|------|-------------|-------|--------|
| 1.1.1 | Fix `state.workspace` possibly undefined error | `extensions/burnbar/src/state/panelViewModel.ts:133` | 5 min |
| 1.1.2 | Add proper null checks where `workspace` is used | `extensions/burnbar/src/state/panelViewModel.ts:133-136` | 10 min |
| 1.1.3 | Verify `npm run build` succeeds | All TypeScript | 5 min |
| 1.1.4 | Run full test suite to verify no regressions | `npm run test:ci` | 5 min |

**Fix Pattern:**
```typescript
// Before (line 133):
const isWorkspaceTrusted = Boolean(state.workspace) && !state.workspace.untrustedWorkspace;

// After:
const isWorkspaceTrusted = Boolean(state.workspace) && !(state.workspace?.untrustedWorkspace ?? false);
```

---

### 1.2 Remove Personal Tool Configuration

**Impact:** Exposes personal developer paths  
**Current Score Improvement:** +0.5 (Exposure Hygiene: 6→7)

| Task | Description | Files | Effort |
|------|-------------|-------|--------|
| 1.2.1 | Remove personal plist file | `tools/com.albertonunez.xcode-deriveddata-switcher.plist` | 2 min |
| 1.2.2 | Update `.gitignore` to exclude `tools/*.plist` | `.gitignore` | 2 min |
| 1.2.3 | Create portable version of xcode-deriveddata-switcher script | `tools/` | 30 min |

**Alternative:** If tool is valuable, make it generic and portable.

---

### 1.3 Delete Firebase Credentials File

**Impact:** CRITICAL - Real credentials on disk  
**Current Score Improvement:** N/A (already not tracked, but verification needed)

| Task | Description | Files | Effort |
|------|-------------|-------|--------|
| 1.3.1 | Delete actual `GoogleService-Info.plist` | `AgentLens/Resources/GoogleService-Info.plist` | 1 min |
| 1.3.2 | Verify file is in `.gitignore` | `.gitignore:61` | 1 min |
| 1.3.3 | Add pre-commit hook to prevent future commits | `.git/hooks/pre-commit` | 15 min |

---

## Phase 2: High Priority (Day 2)

### 2.1 Add Community Health Files

**Impact:** Essential for external contribution  
**Current Score Improvement:** +0.5 (Community Health: 6→7.5)

| Task | Description | Files | Effort |
|------|-------------|-------|--------|
| 2.1.1 | Create bug report issue template | `.github/ISSUE_TEMPLATE/bug_report.md` | 15 min |
| 2.1.2 | Create feature request issue template | `.github/ISSUE_TEMPLATE/feature_request.md` | 15 min |
| 2.1.3 | Create PR template | `.github/PULL_REQUEST_TEMPLATE.md` | 20 min |
| 2.1.4 | Create question/discussion template | `.github/ISSUE_TEMPLATE/question.md` | 10 min |

**Bug Report Template:**
```markdown
---
name: Bug report
about: Create a report to help us improve
title: '[Bug] '
labels: bug
assignees: ''
---

**Describe the bug**
A clear description.

**To Reproduce**
Steps to reproduce.

**Expected behavior**
What you expected.

**Screenshots**
If applicable.

**Environment:**
 - macOS version:
 - BurnBar version:
 - Extension version:

**Additional context**
Anything else.
```

---

### 2.2 Resolve CODEOWNERS Duplication

**Impact:** Repository hygiene  
**Current Score Improvement:** +0.2 (Community: 7.5→7.7)

| Task | Description | Files | Effort |
|------|-------------|-------|--------|
| 2.2.1 | Remove root `CODEOWNERS` file | `CODEOWNERS` | 1 min |
| 2.2.2 | Verify `.github/CODEOWNERS` is correct | `.github/CODEOWNERS` | 2 min |
| 2.2.3 | Ensure GitHub username is consistent | `.github/CODEOWNERS` | 2 min |

---

### 2.3 Address npm Audit Vulnerabilities

**Impact:** Supply chain security  
**Current Score Improvement:** +0.3 (Security: 6→6.5)

| Task | Description | Files | Effort |
|------|-------------|-------|--------|
| 2.3.1 | Update mocha to 11.3.0+ | `extensions/burnbar/package.json` | 10 min |
| 2.3.2 | Verify test suite still passes | `npm run test:unit` | 5 min |
| 2.3.3 | Update lockfile | `package-lock.json` | 2 min |
| 2.3.4 | Run `npm audit` to verify fixes | `npm audit` | 2 min |

**Note:** mocha@11 may have breaking changes to test configuration. Review and adjust `vitest.config.ts` if needed.

---

### 2.4 Address TypeScript Lint Warnings

**Impact:** Code quality polish  
**Current Score Improvement:** +0.2 (Code Quality: 7→7.3)

| Task | Description | Count | Effort |
|------|-------------|-------|--------|
| 2.4.1 | Add default cases to switch statements | ~6 files | 30 min |
| 2.4.2 | Remove unused variables | ~2 files | 10 min |
| 2.4.3 | Remove empty methods or add comments | ~2 files | 10 min |
| 2.4.4 | Replace console.log with console.warn/error | 1 file | 5 min |

---

## Phase 3: Error Handling Remediation (Day 3)

### 3.1 Replace Silent try? Errors in Critical Paths

**Impact:** Production reliability  
**Current Score Improvement:** +0.5 (Code Quality: 7.3→8, Production Credibility: 4→6)

| Task | Description | Files | Effort |
|------|-------------|-------|--------|
| 3.1.1 | Audit try? usage in BurnBarCore | `BurnBarSearchPlanner.swift:838,849` | 15 min |
| 3.1.2 | Audit try? usage in BurnBarDaemon | `BurnBarRunService.swift:169` | 15 min |
| 3.1.3 | Audit try? usage in BurnBarDaemonServer | `BurnBarDaemonServer.swift:120,198,890` | 20 min |
| 3.1.4 | Audit try? usage in other services | `UsageRecorder.swift:127` | 10 min |
| 3.1.5 | Replace with proper error handling or logging | All files | 2-3 hours |

**Categorization Pattern:**
- **Category A (Acceptable Silent):** Optional JSON parsing, non-critical display updates
- **Category B (Log and Continue):** Regex compilation, cache writes, non-essential operations
- **Category C (Propagate):** Database operations, keychain access, network calls

---

## Phase 4: Documentation Polish (Day 4)

### 4.1 Clean Up Internal Documentation

**Impact:** Contributor clarity  
**Current Score Improvement:** +0.3 (Documentation: 8→8.5)

| Task | Description | Files | Effort |
|------|-------------|-------|--------|
| 4.1.1 | Review agent prompt docs for personal references | `docs/BURNBAR_AGENT_PROMPT_PACK.md:10` | 10 min |
| 4.1.2 | Create `.github/INTERNAL_DOCS.md` to clarify | `.github/INTERNAL_DOCS.md` | 15 min |
| 4.1.3 | Add header to internal development docs | All files in `docs/plans/` | 10 min |
| 4.1.4 | Update README to clarify docs structure | `README.md` | 15 min |

**Internal Docs Header:**
```markdown
> **Note:** Files in this directory contain development-internal plans and
> documentation. They are provided for transparency but are not user-facing
> documentation. User documentation is in the main `README.md`.
```

---

### 4.2 Add Quick Start Guide

**Impact:** First-time user experience  
**Current Score Improvement:** +0.2 (Documentation: 8.5→8.7)

| Task | Description | Files | Effort |
|------|-------------|-------|--------|
| 4.2.1 | Create `docs/QUICK_START.md` | `docs/QUICK_START.md` | 30 min |
| 4.2.2 | Add troubleshooting section | `docs/QUICK_START.md` | 20 min |
| 4.2.3 | Add FAQ | `docs/FAQ.md` | 30 min |

---

## Phase 5: Release Engineering (Day 5)

### 5.1 Set Up Release Discipline

**Impact:** Production credibility  
**Current Score Improvement:** +0.5 (Release Engineering: 5→6.5)

| Task | Description | Files | Effort |
|------|-------------|-------|--------|
| 5.1.1 | Create initial git tag v0.1.0-beta | `git tag v0.1.0-beta` | 5 min |
| 5.1.2 | Create release workflow | `.github/workflows/release.yml` | 2 hours |
| 5.1.3 | Add release-it configuration | `release-it.json` | 1 hour |
| 5.1.4 | Document release process | `docs/RELEASE_PROCESS.md` | 30 min |

---

### 5.2 Update CHANGELOG

**Impact:** Release transparency  
**Current Score Improvement:** +0.1 (Release Engineering: 6.5→6.6)

| Task | Description | Files | Effort |
|------|-------------|-------|--------|
| 5.2.1 | Populate CHANGELOG with actual features | `CHANGELOG.md` | 30 min |
| 5.2.2 | Add v0.1.0-beta release entry | `CHANGELOG.md` | 15 min |

---

## Phase 6: Testing Coverage (Week 2)

### 6.1 Add Integration Tests

**Impact:** Engineering confidence  
**Current Score Improvement:** +0.3 (Testing: 8→8.5)

| Task | Description | Files | Effort |
|------|-------------|-------|--------|
| 6.1.1 | Add parser integration tests | `AgentLensTests/ParserIntegration/` | 4 hours |
| 6.1.2 | Add DataStore migration tests | `AgentLensTests/DataStore/` | 3 hours |
| 6.1.3 | Add daemon IPC tests | `BurnBarDaemonTests/` | 3 hours |
| 6.1.4 | Add CI gate for integration tests | `.github/workflows/` | 1 hour |

---

## Phase 7: GitHub Settings Verification (Week 2)

### 7.1 Configure Repository Settings

**Impact:** Security and maintenance  
**Current Score Improvement:** +0.3 (Security: 6.5→7, Community: 7.7→8)

**Note:** These require manual GitHub UI configuration, not file changes.

| Task | Description | Effort |
|------|-------------|--------|
| 7.1.1 | Enable secret scanning | 5 min |
| 7.1.2 | Enable private vulnerability reporting | 5 min |
| 7.1.3 | Enable dependency review | 5 min |
| 7.1.4 | Set up branch protection for main | 10 min |
| 7.1.5 | Add repository topics | `burnbar`, `macos`, `ai-agents`, `productivity` |
| 7.1.6 | Configure GitHub Pages (if docs site) | 15 min |

---

## Consolidated Task List

### Before First Commit (Day 1)

- [ ] 1.1.1-1.1.4: Fix TypeScript build
- [ ] 1.2.1-1.2.3: Remove personal tool config
- [ ] 1.3.1-1.3.3: Delete Firebase credentials

### Before Open-Source Launch (Day 2-3)

- [ ] 2.1.1-2.1.4: Add issue/PR templates
- [ ] 2.2.1-2.2.3: Resolve CODEOWNERS duplication
- [ ] 2.3.1-2.3.4: Fix npm audit vulnerabilities
- [ ] 2.4.1-2.4.4: Address lint warnings
- [ ] 3.1.1-3.1.5: Fix try? error handling
- [ ] 4.1.1-4.1.4: Clean up internal docs
- [ ] 4.2.1-4.2.3: Add quick start guide

### Within 30 Days (Week 2)

- [ ] 5.1.1-5.1.4: Set up release discipline
- [ ] 5.2.1-5.2.2: Update CHANGELOG
- [ ] 6.1.1-6.1.4: Add integration tests
- [ ] 7.1.1-7.1.6: Configure GitHub settings

---

## Score Progression

| Phase | Open-Source Readiness | Notes |
|-------|----------------------|-------|
| Current | 6.5 / 10 | Baseline |
| After Phase 1 | 7.5 / 10 | +1.0 (TS build, +0.5 exposure, +0.2 community) |
| After Phase 2 | 8.0 / 10 | +0.5 (community, security, lint) |
| After Phase 3 | 8.5 / 10 | +0.5 (error handling, code quality) |
| After Phase 4 | 8.7 / 10 | +0.2 (docs polish) |
| After Phase 5 | 9.0 / 10 | +0.3 (release engineering) |
| After Phase 6-7 | 9.0-9.5 / 10 | Testing and GitHub settings |

---

## Success Criteria

| Criterion | Target | Verification |
|-----------|--------|--------------|
| TypeScript build | 0 errors | `npm run build` |
| Swift tests | 0 failures | `swift test --package-path BurnBarCore/Daemon` |
| TypeScript tests | 0 failures | `npm run test:unit` |
| npm audit | 0 high/critical | `npm audit` |
| Lint warnings | < 5 | `npm run lint` |
| Community files | All present | Directory check |
| try? errors | Documented/fixed | Code review |
| Git tag | v0.1.0-beta+ | `git tag -l` |

---

## Risk Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| mocha upgrade breaks tests | Medium | Medium | Run full test suite after upgrade |
| try? changes cause runtime issues | Low | High | Extensive testing after changes |
| Integration tests require significant refactor | Medium | Medium | Scope to critical paths only |

---

## Timeline

| Day | Phase | Deliverables |
|-----|-------|--------------|
| 1 | Phase 1: Critical | TS build passes, secrets removed |
| 2 | Phase 2: High Priority | Templates, audit fixed, lint clean |
| 3 | Phase 3: Error Handling | try? remediated |
| 4 | Phase 4: Docs | Quick start, FAQ, internal doc cleanup |
| 5 | Phase 5: Release | Tag created, workflow set up |
| Week 2 | Phase 6-7 | Integration tests, GitHub config |

**Total Estimated Time:** 5 days focused work + 1 week for testing/refinement

---

## References

- Original Assessment: `docs/QA_REPORT.md`
- Remediation Plans: `plans/2026-04-02-burnbar-*-remediation*.md`
- Security Policy: `SECURITY.md`
