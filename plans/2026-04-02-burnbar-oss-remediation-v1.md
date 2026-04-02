# BurnBar Open-Source Remediation Plan

## Objective

Address all critical blockers and high-priority findings from the open-source readiness assessment to achieve a safe and credible public release.

**Target Completion:** Before first public release
**Current Verdict:** NO-GO (5 critical/high blockers)
**Target Verdict:** CONDITIONAL GO (all blockers resolved)

---

## Blocker Summary

| ID | Finding | Severity | Estimated Effort |
|----|---------|----------|------------------|
| F001 | Hardcoded Google OAuth Client ID | Public Exposure Blocker | 1-2 hours |
| F002 | Missing GitHub Actions/Governance | Public Exposure Blocker | 2-3 hours |
| F003 | App Sandbox Disabled | High | 2-4 hours (or document decision) |
| F004 | Internal Developer Paths Exposed | High | 1-2 hours |
| F005 | Outdated README License Section | Medium | 30 minutes |
| F007 | QA Report Outdated | Medium | 1 hour |
| F010 | Agent Prompt Pack Internal Path | Low | 30 minutes |

---

## Phase 1: Critical Blockers (Before Making Repo Public)

### Task F001: Remove Hardcoded Google OAuth Client ID

**Why:** Exposes real production OAuth credential that could be misused.

**Files to modify:**
- `project.yml:54` - Replace with placeholder `YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com`
- `AgentLens/Resources/BurnBar-Info.plist:26` - Replace with placeholder

**Implementation:**
1. Update `project.yml` to use `YOUR_CLIENT_ID.apps.googleusercontent.com`
2. Update `BurnBar-Info.plist` to use `YOUR_CLIENT_ID.apps.googleusercontent.com`
3. Document in README that users must replace with their own Firebase credentials
4. Verify no other occurrences of `246956661961` anywhere in repo

**Verification:** `grep -r "246956661961" .` returns no results

---

### Task F002: Create GitHub Actions and Governance Infrastructure

**Why:** Security policy, dependency management, and CI/CD are essential for open-source projects.

**Files to create:**

1. `.github/SECURITY.md` - Link from root SECURITY.md or create fresh
   ```markdown
   # Security Policy
   
   ## Supported Versions
   | Version | Supported          |
   | ------- | ------------------ |
   | 0.x     | :white_check_mark: |
   
   ## Reporting a Vulnerability
   [Copy from root SECURITY.md content]
   ```

2. `.github/dependabot.yml`
   ```yaml
   version: 2
   updates:
     - package-ecosystem: "npm"
       directory: "/extensions/burnbar"
       schedule:
         interval: "weekly"
       open-pull-requests-limit: 10
     - package-ecosystem: "swift"
       directory: "/"
       schedule:
         interval: "weekly"
   ```

3. `.github/workflows/ci.yml`
   - Swift build/test for BurnBarCore and BurnBarDaemon
   - npm install + lint + test for extension

4. `.github/CODEOWNERS` (move from root)
   ```
   /AgentLens/ @dewclaw
   /BurnBarCore/ @dewclaw
   /BurnBarDaemon/ @dewclaw
   /extensions/burnbar/ @dewclaw
   /.github/ @dewclaw
   ```

**Verification:** All files exist at specified paths; Dependabot creates PRs within 24 hours

---

### Task F004: Remove Internal Developer Paths

**Why:** Exposes developer identity and local environment.

**Files to modify:**
- `docs/BURNBARDIST_PARITY_PROMPT_PACK.md` (7 occurrences)
- `docs/BURNBAR_AGENT_PROMPT_PACK.md:10`
- Any other files with `/Users/dewclaw/` or `/Users/albertonunez/`

**Implementation:**
1. Replace `/Users/dewclaw/Documents/Projects/BurnBar` with `$PROJECT_ROOT` or `BurnBar`
2. Replace `/Users/dewclaw/BurnBarDist` with `$BURNBARDIST_DIR` or `BurnBarDist`
3. Replace `/Users/albertonunez/Developer/AgentLens` with `$REPO_ROOT`
4. Update any relative paths to use repo-root-relative references

**Verification:** `grep -r "/Users/" docs/` returns no results; `grep -r "albertonunez" .` returns no results

---

## Phase 2: High Priority (Before First Tagged Release)

### Task F003: Address App Sandbox Decision

**Why:** App runs without macOS sandbox protection.

**Options:**

**Option A - Document Intentional Non-Sandboxing (Recommended for Developer ID distribution):**
1. Update `BurnBar.entitlements` to include `com.apple.security.app-sandbox: false` with comment explaining rationale
2. Add "Security Notes" section to README explaining:
   - App requires filesystem access for reading AI agent log files from user home directory
   - Keychain access required for API key storage
   - Sandbox is incompatible with core functionality
   - Developer ID signing provides alternative security boundary

**Option B - Enable Sandbox:**
1. Update entitlements with appropriate sandbox settings
2. Test all features work under sandbox
3. Document limitations

**Verification:** `grep -A1 "app-sandbox" AgentLens/Resources/BurnBar.entitlements` shows documented decision

---

### Task F007: Update QA Report

**Why:** Outdated documentation claims "zero test coverage" when extensive tests exist.

**Implementation:**
1. Update `docs/QA_REPORT.md`:
   - Change date to current
   - Remove or update claim about no automated tests
   - Document actual test coverage (~35 test files)
   - Update build status and residual risks
2. Alternative: Archive old QA report and create new one

**Verification:** QA report accurately reflects current state

---

## Phase 3: Medium Priority

### Task F005: Update README License Section

**Why:** README claims no LICENSE file exists when MIT license is present.

**Implementation:**
1. Find and remove the TODO comment in README about LICENSE (line ~360-361)
2. Replace with accurate reference: "Licensed under MIT License - see [LICENSE](LICENSE)"
3. Remove any placeholder text about "figure out the legal bit"

**Verification:** README license section accurately describes actual license

---

### Task F010: Remove Absolute Path from Agent Prompt Pack

**Why:** Exposes developer identity.

**Implementation:**
1. Update `docs/BURNBAR_AGENT_PROMPT_PACK.md:10`
2. Change from: `You are working in /Users/albertonunez/Developer/AgentLens on branch main.`
3. Change to: `You are working in the BurnBar repository on branch main.`

**Verification:** `grep -n "albertonunez" .` returns no results

---

### Task F008: Audit try? Error Handling

**Why:** Silent failures on critical paths make debugging difficult.

**Implementation (tracked separately, not blocking release):**
1. Create tracking issue for try? audit
2. Categorize existing try? usages by impact:
   - Category A: Acceptable silent failure (e.g., optional JSON parsing)
   - Category B: Log and continue (e.g., regex compilation)
   - Category C: Propagate error (e.g., database operations, keychain)
3. Fix Category C errors before 1.0 release

**Reference:** `plans/2026-04-02-burnbar-launch-blockers-remediation-v1.md:54-60` has full file list

---

## Phase 4: Release Infrastructure (Before First Release Tag)

### Task Release-01: Create Release Tag

**Implementation:**
1. Create `v0.1.0-beta` or `v0.9.0` tag (not v1.0.0 since claiming production maturity)
2. Update `project.yml:15` MARKETING_VERSION to match
3. Document release in CHANGELOG

### Task Release-02: Document Notarization Process

**Implementation:**
1. Review `docs/RELEASE_MACOS.md` accuracy
2. Add any missing steps for Developer ID signing and notarization
3. Document code signing requirements

### Task Release-03: Add CI/CD Pipeline

**Implementation:**
1. Create `.github/workflows/ci.yml` with:
   - Swift build and test
   - npm lint and test for extension
   - Coverage reporting
2. Add `README.md` badge for CI status (once workflow exists)

---

## Verification Checklist

Before declaring release-ready, verify:

### Critical Blockers:
- [ ] `grep -r "246956661961" .` returns no results
- [ ] `.github/SECURITY.md` exists
- [ ] `.github/dependabot.yml` exists
- [ ] `.github/workflows/ci.yml` exists
- [ ] `.github/CODEOWNERS` exists
- [ ] `grep -r "/Users/dewclaw/" docs/` returns no results
- [ ] `grep -r "albertonunez" .` returns no results

### High Priority:
- [ ] `BurnBar.entitlements` contains documented sandbox decision
- [ ] `docs/QA_REPORT.md` is current (dated within 30 days) or archived
- [ ] README license section is accurate

### Nice to Have:
- [ ] CI badge in README
- [ ] Release tag exists
- [ ] Notarization documentation is complete

---

## Success Metrics

| Metric | Target | Verification |
|--------|--------|--------------|
| OAuth client ID exposed | 0 occurrences | `grep -r "246956661961" .` |
| GitHub governance files | All present | File existence check |
| Internal paths exposed | 0 occurrences | `grep -r "/Users/" docs/` |
| README accuracy | All sections current | Manual review |
| Release tag | Exists | `git tag -l` |

---

## Timeline Estimate

| Phase | Tasks | Effort |
|-------|-------|--------|
| Phase 1: Critical Blockers | F001, F002, F004 | 5-7 hours |
| Phase 2: High Priority | F003, F007 | 3-5 hours |
| Phase 3: Medium Priority | F005, F010, F008 (tracked) | 2-3 hours |
| Phase 4: Release Infrastructure | Release-01, 02, 03 | 2-3 hours |
| **Total** | **12 tasks** | **12-18 hours** |

---

## Post-Release Recommendations

Within 30 days of open-source launch:
1. Enable GitHub Security Advisories
2. Set up automated dependency updates via Dependabot
3. Add issue and pull request templates
4. Monitor for any accidentally committed secrets in future commits
5. Consider adding secret scanning at repository level