# Parked Tests

Files in this directory are intentionally **not** compiled by `OpenBurnBarTests`.

They remain in-repo as reference material or future revival candidates, but contributors should treat them as archival unless a change explicitly moves them back under `AgentLensTests/Active/`.

## Re-enable checklist

1. Move the suite back under `AgentLensTests/Active/` and any shared helpers under `AgentLensTests/Support/`.
2. Regenerate the Xcode project with `xcodegen generate`.
3. Fix compile/runtime drift against current app and daemon APIs.
4. Run `./scripts/test-openburnbar-app.sh` locally before depending on CI.
