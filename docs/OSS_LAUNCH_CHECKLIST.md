# BurnBar OSS Launch Checklist

This file tracks launch settings that cannot be inferred from the working tree alone.

Re-check every item immediately before changing repository visibility.

## Confirmed via GitHub API on 2026-04-02

- Repository visibility: `private`
- Default branch: `main`
- Issues: enabled
- Wiki: enabled
- Branch protection on `main`: enabled
- Required status checks on `main`: `burnbar-pr9-harness` with strict mode enabled
- Required pull request reviews on `main`: 1 approval
- Dismiss stale reviews: enabled
- Enforce admins: enabled
- Force pushes: disabled
- Branch deletions: disabled
- SECURITY policy recognized by GitHub: yes

## Confirmed from working tree on 2026-04-02

### Community files (.github/)
- [x] `CODEOWNERS` — defines ownership for AgentLens/, BurnBarCore/, BurnBarDaemon/, extensions/
- [x] `ISSUE_TEMPLATE/bug_report.md` — bug report form with version, component, steps to reproduce
- [x] `ISSUE_TEMPLATE/feature_request.md` — feature request form with problem/solution template
- [x] `PULL_REQUEST_TEMPLATE.md` — PR checklist with testing, breaking change, documentation sections
- [x] `SECURITY.md` — private vulnerability reporting path, security best practices

### CI/CD workflows (.github/workflows/)
- [x] `burnbar-pr9-harness.yml` — PR validation: Swift tests, app tests, retrieval evals, TS tests, replay evals, extension-host tests
- [x] `release.yml` — tagged prerelease: builds extension, daemon, creates draft GitHub Release

### Dependency management
- [x] `dependabot.yml` — configured for npm (extensions/burnbar), Swift (BurnBarCore, BurnBarDaemon), and GitHub Actions

## Confirmed from registry/package metadata on 2026-04-02

- npm package name `burnbar`: not present in the public npm registry at the time of check

## Still needs manual confirmation before public launch

- [ ] Private vulnerability reporting setting (enable in repository settings)
- [ ] Secret scanning setting (enable in repository settings)
- [ ] Code scanning / advisory triage state
- [ ] Whether the single current vulnerability alert has been reviewed and is acceptable for launch
- [ ] Repository description, topics, and homepage URL
- [ ] Whether wiki should remain enabled
- [ ] Whether Discussions should be enabled

## Action required at launch time

- [ ] Create annotated git tag: `git tag -a v0.1.0-beta -m "Initial experimental source release" && git push origin v0.1.0-beta`

## Post-launch considerations

- [ ] Naming and trademark clearance for broader public distribution under the name `BurnBar`
- [ ] Consider reserving npm package name `burnbar` if not already taken
- [ ] Consider setting up a GitHub Pages site for documentation if wiki is disabled
