# AgentLensTests

## Folder contract

The Xcode unit-test target **`OpenBurnBarTests`** is generated from [`project.yml`](../project.yml). It compiles by directory, not by an ad-hoc file list:

- `AgentLensTests/Active/` — active XCTest suites compiled in `OpenBurnBarTests`
- `AgentLensTests/Support/` — shared harnesses and helpers used by active suites
- `AgentLensTests/Parked/` — in-repo reference/archival tests that are intentionally **not** compiled
- `AgentLensTests/Fixtures/` — fixtures shared by active/support code

The active target is intentionally limited to `Active/**` plus `Support/**`.

## Active bundle

Run the active bundle:

```bash
./scripts/test-openburnbar-app.sh
# or
xcodebuild -scheme OpenBurnBar -project OpenBurnBar.xcodeproj -destination 'platform=macOS' test \
  CODE_SIGNING_ALLOWED=NO -only-testing:OpenBurnBarTests
```

Representative active suites now live under `AgentLensTests/Active/`, including the replay golden tests, discovery/retrieval coverage, settings secret-storage coverage, and the smaller standalone app test files that used to live at the root of `AgentLensTests/`.

## Parked bundle

Everything under `AgentLensTests/Parked/` stays in-repo for future revival, but it does not affect CI or contributor verification until it is moved back into `Active/` and brought up to date.
