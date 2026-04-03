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

## Confirmed from registry/package metadata on 2026-04-02

- npm package name `burnbar`: not present in the public npm registry at the time of check

## Still needs manual confirmation before public launch

- Private vulnerability reporting setting
- Secret scanning setting
- Code scanning / advisory triage state
- Whether the single current vulnerability alert has been reviewed and is acceptable for launch
- Repository description, topics, and homepage URL
- Whether wiki should remain enabled
- Whether Discussions should be enabled
- Whether a matching public git tag (`v0.1.0-beta`) should be created at launch time
- Naming and trademark clearance for broader public distribution under the name `BurnBar`
