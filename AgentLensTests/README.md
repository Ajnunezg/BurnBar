# AgentLensTests — active vs parked

## Active (compiled in `BurnBarTests`)

The Xcode unit-test target **`BurnBarTests`** is generated from [`project.yml`](../project.yml). It intentionally includes only:

| File | Role |
|------|------|
| `AgentLensTests.swift` | Baseline app test entry |
| `BurnBarSearchIntegrationHarness.swift` | Search replay / eval harness used in public CI |

Run the active bundle:

```bash
./scripts/test-burnbar-app.sh
# or
xcodebuild -scheme BurnBar -project BurnBar.xcodeproj -destination 'platform=macOS' test \
  CODE_SIGNING_ALLOWED=NO -only-testing:BurnBarTests
```

## Parked (not compiled)

Many other `*.swift` files in this directory (e.g. older UI tests, `DataStoreTests`, parser tests) **are not** listed under `BurnBarTests.sources` in `project.yml`. They remain in-repo as reference or for future revival but **do not compile** with the current Xcode project, so they do not affect CI until re-enabled.

### Re-enable checklist

1. Add the file path(s) to `project.yml` → `targets` → `BurnBarTests` → `sources`.
2. Regenerate the Xcode project if you use XcodeGen (`xcodegen generate`).
3. Fix compile errors against current app/daemon APIs.
4. Run `./scripts/test-burnbar-app.sh` locally before relying on CI.
