#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

swift test --package-path "$repo_root/OpenBurnBarCore"
swift test --package-path "$repo_root/OpenBurnBarDaemon"
