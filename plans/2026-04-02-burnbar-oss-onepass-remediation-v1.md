# BurnBar Open-Source Remediation — One-Pass Maximum-Effort Plan

## Objective

Fix all public-exposure blockers and bootstrap the minimum viable open-source infrastructure in a single focused pass. Every action below is verified against the codebase, tied to a specific finding from the readiness assessment, and executable without additional research.

---

## Verdict Context

- **Public OSS release verdict:** `NO-GO` — 6 material blockers
- **Engineering quality:** `7/10` — no code changes needed
- **OSS readiness:** `5/10` — all gaps are administrative, not technical
- **All 14 items below must be completed before the repo is made public.**

---

## Implementation Plan

> **MANDATORY CHECKBOX FORMAT — execute every item**

---

### PHASE 1: Internal Documentation Scrub (Critical — 5 minutes)

- [ ] **1.1.** Delete the entire `plans/` directory. All 14 files expose internal process, remediation thinking, and the open-sourcing decision itself. None belong in a public repo.
  ```
  rm -rf plans/
  ```
  **Rationale:** F-05 / F-12 from the assessment. Files include `2026-04-02-burnbar-oss-remediation-v1.md`, `2026-04-01-mission-control-swift-remediation-v1.md`, and 12 others — all internal planning documents.

- [ ] **1.2.** Remove or replace `CLAUDE.md` at the root. AI assistant instruction files are atypical in OSS repos and this one contains absolute local paths (for example `/Users/example/BurnBarDist`, `/Users/example/`, `/Users/other-developer/`).
  ```
  rm CLAUDE.md
  ```
  **Alternative if content is valuable:** Replace with a sanitized `.cursorrules` that uses only relative paths and generic instructions. Do NOT keep the current version.
  **Rationale:** F-06 from the assessment.

- [ ] **1.3.** Create `.gitignore` entry for any accidental `.env`, `.pem`, or credential files that might have been staged but not yet committed. The current `.gitignore:57-59` already covers these, but verify no stragglers:
  ```
  git status --short | grep -E "\.env|\.pem|\.p12|secret|credential"
  ```
  If anything matches, remove it before proceeding.
  **Rationale:** Belt-and-suspenders confirmation pass.

---

### PHASE 2: Documentation Sanitization (Critical — 10 minutes)

- [ ] **2.1.** In `README.md:251`, replace the personal GitHub clone URL. Before making public, decide the final URL. Use a placeholder until confirmed:
  ```diff
  - git clone https://github.com/YOUR_ORG/BurnBar.git
  + git clone https://github.com/YOUR_ORG/BurnBar.git
  ```
  **Rationale:** F-01 from the assessment. All three instances (README.md:251, QUICKSTART.md:18, QUICKSTART.md:152) must be updated simultaneously.

- [ ] **2.2.** In `QUICKSTART.md:18` and `QUICKSTART.md:152`, replace the same personal GitHub URL:
  ```diff
  - git clone https://github.com/YOUR_ORG/BurnBar.git
  + git clone https://github.com/YOUR_ORG/BurnBar.git
  ```
  ```diff
  - **Bug reports:** [GitHub Issues](https://github.com/YOUR_ORG/BurnBar/issues)
  + **Bug reports:** [GitHub Issues](https://github.com/YOUR_ORG/BurnBar/issues)
  ```

- [ ] **2.3.** In `README.md:35`, remove the TODO placeholder or replace with a note:
  ```diff
  - <!-- TODO: Add screenshot — ideally one popover, one dashboard, one "oh no" spend spike -->
  + <!-- Screenshots: pending legal/design review -->
  ```

- [ ] **2.4.** In `CHANGELOG.md`, replace empty content with a proper initial entry:
  ```markdown
  # Changelog

  ## 0.1.0-beta (Initial Beta)

  First public beta release.

  ### Added
  - Menu bar application tracking AI agent token usage and cost
  - Local SQLite persistence with GRDB
  - Support for parsing session logs from Claude Code, Factory/Droid, Codex, and other providers
  - Optional Firebase Auth + Firestore sync
  - Optional iCloud mirroring
  - VS Code / Cursor extension (`extensions/burnbar/`)
  - Local JSON-RPC daemon for editor integration
  - Hybrid lexical (FTS5) + semantic search
  - Floating dashboard with provider breakdowns and spend insights

  ### Known Limitations
  - This is a beta release. API and data schema may change.
  - Firebase configuration requires manual setup (see QUICKSTART.md).
  ```
  **Rationale:** F-08 from the assessment. Empty CHANGELOG is misleading.

---

### PHASE 3: Bootstrap `.github/` Directory (Critical — 20 minutes)

> Create the `.github/` directory with all community health files at once.

- [ ] **3.1.** Create `.github/CODEOWNERS`:
  ```github
  # BurnBar Core Ownership
  # Replace @maintainer with actual GitHub username(s) before making public

  # Global default — everything falls back to this unless overridden
  * @maintainer

  # Granular ownership (add as maintainers are identified)
  AgentLens/        @maintainer
  BurnBarCore/      @maintainer
  BurnBarDaemon/    @maintainer
  extensions/      @maintainer
  ```

- [ ] **3.2.** Create `.github/ISSUE_TEMPLATE/bug_report.md`:
  ```markdown
  name: Bug Report
  description: Report something that is broken
  title: "[Bug] "
  labels: ["bug"]
  assignees: []
  body:
    - type: markdown
      attributes:
        value: |
          ## Bug Description
          A clear description of the bug.

    - type: textarea
      id: steps
      attributes:
        label: Steps to Reproduce
        description: Exact steps to reproduce the issue
        placeholder: |
          1. Go to '...'
          2. Click on '...'
          3. See error
      validations:
        required: true

    - type: textarea
      id: expected
      attributes:
        label: Expected Behavior
        description: What should happen
      validations:
        required: true

    - type: textarea
      id: actual
      attributes:
        label: Actual Behavior
        description: What actually happens
      validations:
        required: true

    - type: input
      id: version
      attributes:
        label: BurnBar Version
        description: "Version (e.g., 0.1.0-beta)"
      validations:
        required: false

    - type: input
      id: os
      attributes:
        label: macOS Version
        description: "e.g., macOS 14.3"
      validations:
        required: false

    - type: textarea
      id: logs
      attributes:
        label: Relevant Log Output
        description: Paste any relevant log output (redact API keys/tokens)
        render: shell
      validations:
        required: false
  ```

- [ ] **3.3.** Create `.github/ISSUE_TEMPLATE/feature_request.md`:
  ```markdown
  name: Feature Request
  description: Suggest a new feature or improvement
  title: "[Feature] "
  labels: ["enhancement"]
  assignees: []
  body:
    - type: markdown
      attributes:
        value: |
          ## Feature Summary
          A brief description of the feature or improvement you'd like.

    - type: textarea
      id: motivation
      attributes:
        label: Motivation
        description: Why do you need this feature? What problem does it solve?
        placeholder: |
          I want to track [...] so that [...]
      validations:
        required: true

    - type: textarea
      id: proposed
      attributes:
        label: Proposed Solution
        description: How do you envision this working?
      validations:
        required: true

    - type: textarea
      id: alternatives
      attributes:
        label: Alternatives Considered
        description: Any other approaches you considered
      validations:
        required: false
  ```

- [ ] **3.4.** Create `.github/PULL_REQUEST_TEMPLATE.md`:
  ```markdown
  ## Description
  Briefly describe the changes in this PR.

  ## Type of Change
  - [ ] Bug fix
  - [ ] New feature
  - [ ] Breaking change
  - [ ] Documentation update
  - [ ] Refactoring

  ## Testing
  Describe what testing you performed.
  - [ ] Unit tests added/updated
  - [ ] Tested locally on macOS

  ## Checklist
  - [ ] Code follows the project's style guidelines
  - [ ] Self-reviewed the changes
  - [ ] Added comments for complex code
  - [ ] Updated documentation if needed
  - [ ] No new warnings or errors introduced
  ```

- [ ] **3.5.** Create `.github/FUNDING.yml`:
  ```yaml
  # Replace with appropriate funding platforms
  github: []
  # ko_fi: username
  # patreon: username
  # open_collective: burnbar
  # tidelift: npm/burnbar
  ```

---

### PHASE 4: GitHub Actions CI Pipeline (Critical — 30 minutes)

- [ ] **4.1.** Create `.github/workflows/swift-ci.yml`:
  ```yaml
  name: Swift CI

  on:
    push:
      branches: [main]
    pull_request:
      branches: [main]

  jobs:
    build-and-test:
      runs-on: macos-14
      timeout-minutes: 30

      steps:
        - uses: actions/checkout@v4

        - name: Select Xcode
          run: sudo xcode-select -s /Applications/Xcode.app && xcodebuild -version

        - name: Generate Xcode Project
          run: brew install xcodegen && xcodegen generate

        - name: Build BurnBar
          run: xcodebuild -project BurnBar.xcodeproj -scheme BurnBar -configuration Debug build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO 2>&1 | tail -20

        - name: Build BurnBarCore
          run: swift build --package-path BurnBarCore

        - name: Build BurnBarDaemon
          run: swift build --package-path BurnBarDaemon

        - name: Run BurnBarCore Tests
          run: swift test --package-path BurnBarCore

        - name: Run BurnBarDaemon Tests
          run: swift test --package-path BurnBarDaemon

        - name: Run BurnBar App Tests
          run: xcodebuild -project BurnBar.xcodeproj -scheme BurnBarTests -configuration Debug test CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10

    swiftlint:
      runs-on: macos-14
      steps:
        - uses: actions/checkout@v4
        - name: Run SwiftLint
          run: |
            brew install swiftlint
            swiftlint || true
  ```

- [ ] **4.2.** Create `.github/workflows/extension-ci.yml`:
  ```yaml
  name: VS Code Extension CI

  on:
    push:
      branches: [main]
      paths: ["extensions/**"]
    pull_request:
      branches: [main]
      paths: ["extensions/**"]

  jobs:
    lint-and-build:
      runs-on: ubuntu-latest
      defaults:
        run:
          working-directory: extensions/burnbar

      steps:
        - uses: actions/checkout@v4

        - uses: actions/setup-node@v4
          with:
            node-version: "20"
            cache: "npm"
            cache-dependency-path: extensions/burnbar/package-lock.json

        - run: npm ci

        - run: npm run lint

        - run: npm run build
  ```

- [ ] **4.3.** Create `.github/workflows/codeql.yml`:
  ```yaml
  name: CodeQL Security Analysis

  on:
    push:
      branches: [main]
    pull_request:
      branches: [main]

  jobs:
    codeql:
      runs-on: macos-14
      permissions:
        security-events: write
        contents: read

      steps:
        - uses: actions/checkout@v4

        - name: Select Xcode
          run: sudo xcode-select -s /Applications/Xcode.app

        - uses: github/codeql-action/init@v3
          with:
            languages: swift
            queries: security-extended

        - uses: github/codeql-action/analyze@v3
  ```

- [ ] **4.4.** Create `.github/dependabot.yml`:
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
      open-pull-requests-limit: 10
  ```

---

### PHASE 5: Final Pre-Publication Hygiene (5 minutes)

- [ ] **5.1.** Verify no personal references remain:
  ```bash
  grep -r "YOUR_GITHUB_HANDLE\|/Users/example\|/Users/other-developer\|BurnBarDist" --include="*.md" --include="*.swift" --include="*.yml" --include="*.json" --include="*.ts" .
  ```
  Expected: **zero results** before publication.

- [ ] **5.2.** Verify `plans/` is gone:
  ```bash
  ls plans/ 2>&1
  ```
  Expected: `No such file or directory`.

- [ ] **5.3.** Verify `.github/` is complete:
  ```bash
  find .github -type f | sort
  ```
  Expected: CODEOWNERS, FUNDING.yml, ISSUE_TEMPLATE/bug_report.md, ISSUE_TEMPLATE/feature_request.md, PULL_REQUEST_TEMPLATE.md, workflows/codeql.yml, workflows/extension-ci.yml, workflows/swift-ci.yml, dependabot.yml (9 files total).

- [ ] **5.4.** Verify `CLAUDE.md` is gone:
  ```bash
  ls CLAUDE.md 2>&1
  ```
  Expected: `No such file or directory`.

- [ ] **5.5.** Verify README TODO is addressed:
  ```bash
  grep -n "TODO" README.md
  ```
  Expected: zero results in README.md body (the CHANGELOG entry about "beta" is fine).

- [ ] **5.6.** Verify CHANGELOG has content:
  ```bash
  wc -l CHANGELOG.md
  ```
  Expected: > 5 lines with actual content.

- [ ] **5.7.** Run a final `git status` and review every untracked/modified file. Commit nothing that was not intentionally added in this pass.

---

## Verification Criteria

- [ ] `plans/` directory does not exist
- [ ] `CLAUDE.md` does not exist
- [ ] `README.md`, `QUICKSTART.md` contain no personal account references
- [ ] `README.md` contains no `TODO:` comment
- [ ] `CHANGELOG.md` contains an initial `0.1.0-beta` entry
- [ ] `.github/CODEOWNERS` exists and references correct maintainer(s)
- [ ] `.github/ISSUE_TEMPLATE/bug_report.md` exists
- [ ] `.github/ISSUE_TEMPLATE/feature_request.md` exists
- [ ] `.github/PULL_REQUEST_TEMPLATE.md` exists
- [ ] `.github/workflows/swift-ci.yml` exists and references all 4 targets
- [ ] `.github/workflows/extension-ci.yml` exists for the VS Code extension
- [ ] `.github/workflows/codeql.yml` exists for security scanning
- [ ] `.github/dependabot.yml` exists for automated dependency updates
- [ ] No personal paths (for example `/Users/example/`, `/Users/other-developer/`) anywhere in the repo
- [ ] GitHub Actions workflow files have `on: [push, pull_request]` triggers
- [ ] CI workflow uses pinned action versions (`@v4`, `@v3`)

---

## Potential Risks and Mitigations

1. **Risk:** Deleting `plans/` loses valuable internal documentation.
   **Mitigation:** Copy the directory to a private location before deleting. The content is planning documents, not code — nothing irreplaceable.

2. **Risk:** Removing `CLAUDE.md` means AI coding assistants lose context.
   **Mitigation:** Create a sanitized `.cursorrules` or `.claude/` directory with only generic, path-independent instructions before the repo goes public.

3. **Risk:** The Swift CI workflow may fail on first run due to missing Xcode licensing or missing homebrew packages.
   **Mitigation:** Add `brew install swiftlint` as a conditional step, and consider adding `xcode-select` fallback. Test the workflow on a fork before merging to main.

4. **Risk:** Changing GitHub URLs from a personal account to `YOUR_ORG` in docs creates broken links if the final URL is not decided.
   **Mitigation:** Make the URL decision a prerequisite. Use `https://github.com/burnbar-oss/BurnBar` as a reasonable placeholder that is easy to update with a global search-and-replace once the org is created.

5. **Risk:** CodeQL may surface issues in the existing codebase that create pressure to fix before launch.
   **Mitigation:** Run CodeQL before making public so you know what it will find. Consider setting it to only block merges on new issues, not existing ones.

---

## Alternative Approaches

1. **Keep `CLAUDE.md` but sanitize it:** Instead of deleting, rewrite to remove all absolute paths. This preserves AI coding context for contributors using Cursor/Claude Code. Trade-off: more effort, requires careful manual review.

2. **Skip CodeQL for now:** Security scanning can be added post-launch. Trade-off: slightly lower initial security posture, but cleaner first PR if the codebase has pre-existing issues CodeQL would flag.

3. **Use a monorepo CI template:** Instead of hand-writing the workflows, use `actions/quickstart/workflow-templates` or a community Swift CI action. Trade-off: less control over specifics, but faster setup and community-maintained.

4. **Keep `plans/` as a private submodule:** Instead of deleting, move it to a private repo and reference it as a git submodule. Trade-off: more complex git setup, creates a second dependency.

5. **Delay public launch until an organization is created:** The URL decision is a blocker for Phase 2. The project could launch under a personal-account repository temporarily and transfer later, but this creates double the URL updates. Trade-off: launch sooner vs. launch cleaner.

---

## Effort Estimate

| Phase | Item | Estimated Time |
|-------|------|---------------|
| Phase 1 | Delete plans/, CLAUDE.md, verify gitignore | 5 min |
| Phase 2 | Fix 3 GitHub URLs, remove README TODO, populate CHANGELOG | 10 min |
| Phase 3 | Create 5 .github/ files (CODEOWNERS, 2 issue templates, PR template, FUNDING) | 20 min |
| Phase 4 | Create 4 workflow/config files (.github/workflows/* 3, dependabot.yml 1) | 30 min |
| Phase 5 | Run all verification checks | 5 min |
| **Total** | **All 14 actionable items** | **~70 minutes** |

---

## Post-Publication Recommendations (Not Required Before Launch)

- Enable GitHub's built-in secret scanning and Dependabot alerts on the repository settings page (these are repository-level settings, not file-based)
- Set branch protection rules on `main` (require PR reviews, require status checks to pass)
- Add GitHub Topics to the repository (`macos`, `swift`, `ai`, `token-tracking`, `menu-bar`, etc.)
- Add a repository description and website URL
- Publish a first release (`0.1.0-beta`) with the CHANGELOG entry as the release body
- Add `license` and `CI` badges to README once workflows are confirmed passing
